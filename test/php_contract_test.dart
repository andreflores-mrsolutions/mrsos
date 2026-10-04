import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/services/auth_service.dart';
import 'package:mrsos/services/index_service.dart';
import 'package:mrsos/services/push_service.dart';
import 'package:mrsos/services/session_store.dart';
import 'package:mrsos/services/ticket_catalog_service.dart';
import 'package:mrsos/services/notification_service.dart';
import 'package:mrsos/config/app_config.dart';
import 'package:mrsos/services/schedule_service.dart';
import 'package:mrsos/services/survey_service.dart';
import 'package:mrsos/services/reportes_service.dart';
import 'package:mrsos/services/equipos_service.dart';

class FakePhp implements HttpClientAdapter {
  FakePhp(this.reply);
  final FutureOr<ResponseBody> Function(RequestOptions) reply;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    if (body != null) await body.drain<void>();
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  Object body, {
  int status = 200,
  bool cookie = false,
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    'content-type': ['application/json'],
    if (cookie)
      'set-cookie': ['PHPSESSID=test-session; Path=/; HttpOnly; Secure'],
  },
);

const serverSession = {
  'success': true,
  'usId': 42,
  'usNombre': 'Cuenta de prueba',
  'rol': 'CLI',
  'clId': 8,
  'ucrRol': 'ADMIN_SEDE',
  'csId': 7,
  'czId': null,
  'csrfToken': 'test-csrf',
  'usConfirmado': 'Si',
  'legalAccepted': true,
  'legalVersion': '2026-10-02.1',
  'preferences': {'notifInApp': true, 'notifMail': false},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHttp http;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    http = AppHttp.create(baseUrl: 'https://test.invalid/php');
  });

  test(
    'login uses the web contract and obtains the authoritative client scope',
    () async {
      final adapter = FakePhp(
        (r) =>
            r.uri.path.endsWith('/login.php')
                ? jsonResponse({
                  'success': true,
                  'user': 'Name',
                  'csrfToken': 'login-token',
                }, cookie: true)
                : jsonResponse(serverSession),
      );
      http.dio.httpClientAdapter = adapter;
      final result = await AuthService(
        dio: http.dio,
        loginPath: '/login.php',
      ).login(usId: 'someone', usPass: 'test-only');
      expect(result.user!['usId'], 42);
      expect(result.user!['clId'], 8);
      expect(http.csrfToken, 'test-csrf');
      expect(
        adapter.requests.last.headers['cookie'],
        contains('PHPSESSID=test-session'),
      );
      expect(adapter.requests.first.uri.path, '/php/login.php');
      expect(
        adapter.requests.first.headers['X-Requested-With'],
        'XMLHttpRequest',
      );
    },
  );

  test(
    'concurrent POSTs share one me.php request and send CSRF with JSON/multipart',
    () async {
      final adapter = FakePhp(
        (r) => jsonResponse(
          r.uri.path.endsWith('/me.php') ? serverSession : {'success': true},
        ),
      );
      http.dio.httpClientAdapter = adapter;
      await Future.wait([
        http.dio.post('/notification_read.php', data: {'id': 1}),
        http.dio.post(
          '/actualizar_perfil.php',
          data: FormData.fromMap({'usNombre': 'Test'}),
        ),
      ]);
      expect(
        adapter.requests.where((r) => r.uri.path.endsWith('/me.php')).length,
        1,
      );
      for (final r in adapter.requests.where((r) => r.method == 'POST')) {
        expect(r.headers['X-CSRF-Token'], 'test-csrf');
      }
    },
  );

  test(
    '419 never replays a mutation and clears the token for the next attempt',
    () async {
      http.csrfToken = 'expired';
      final adapter = FakePhp(
        (_) =>
            jsonResponse({'success': false, 'error': 'expired'}, status: 419),
      );
      http.dio.httpClientAdapter = adapter;
      await expectLater(
        http.dio.post('/ticket_create.php', data: {'x': 1}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests.length, 1);
      expect(http.csrfToken, isNull);
    },
  );

  test(
    '401 expires the session but invalid login does not trigger global logout',
    () async {
      var expired = 0;
      http.onSessionExpired = () => expired++;
      http.dio.httpClientAdapter = FakePhp(
        (_) => jsonResponse({'success': false}, status: 401),
      );
      await expectLater(http.dio.get('/me.php'), throwsA(isA<DioException>()));
      await expectLater(
        http.dio.post('/login.php', data: {}),
        throwsA(isA<DioException>()),
      );
      expect(expired, 1);
    },
  );

  test(
    'rejects cross-origin requests before sending cookies or CSRF',
    () async {
      final adapter = FakePhp((_) => jsonResponse({'success': true}));
      http.dio.httpClientAdapter = adapter;
      await expectLater(
        http.dio.get('https://external.invalid/file'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'HTTP 200 success=false and HTML are not accepted as empty successful data',
    () async {
      http.dio.httpClientAdapter = FakePhp(
        (_) => jsonResponse({'success': false, 'error': 'Sin alcance'}),
      );
      await expectLater(
        http.dio.get('/data.php'),
        throwsA(isA<DioException>()),
      );
      http.dio.httpClientAdapter = FakePhp(
        (_) => ResponseBody.fromString('<html>Login</html>', 200),
      );
      await expectLater(
        http.dio.get('/data.php'),
        throwsA(isA<DioException>()),
      );
    },
  );

  test(
    'device identifier survives logout; old account scope and preferences do not',
    () async {
      final device = DeviceRegistration(http.dio);
      final id = await device.deviceId();
      await SessionStore.saveServerSession(serverSession);
      await SessionStore.saveServerSession({
        ...serverSession,
        'csId': null,
        'clId': 9,
      });
      expect((await SessionStore().getProfile())['csId'], isNull);
      await http.clearSession();
      expect(await device.deviceId(), id);
      expect(await SessionStore.isLogged(), isFalse);
    },
  );

  for (final platform in ['android', 'ios']) {
    test(
      'registers $platform in user_push_devices and removes only this device',
      () async {
        http.csrfToken = 'csrf';
        final adapter = FakePhp((_) => jsonResponse({'success': true}));
        http.dio.httpClientAdapter = adapter;
        final device = DeviceRegistration(http.dio);
        await device.register(
          'valid-fcm-token-for-contract-testing-12345',
          platform,
        );
        final payload = adapter.requests.first.data as Map;
        expect(payload.keys.toSet(), {
          'deviceId',
          'platform',
          'token',
          'csrf_token',
        });
        expect(payload['csrf_token'], 'csrf');
        expect(payload['platform'], platform);
        await device.remove();
        expect(adapter.requests.last.uri.path, '/php/notif_token_eliminar.php');
        expect(adapter.requests.last.data['deviceId'], payload['deviceId']);
      },
    );
  }

  test(
    'catalog uses current endpoints, real site IDs and peId instead of model IDs',
    () async {
      http.csrfToken = 'csrf';
      http.dio.httpClientAdapter = FakePhp(
        (r) => jsonResponse(
          r.uri.path.endsWith('sedes.php')
              ? {
                'success': true,
                'sedes': [
                  {
                    'csId': '9',
                    'csNombre': 'Sede',
                    'healthCheckAvailable': true,
                  },
                ],
              }
              : {
                'success': true,
                'equipos': [
                  {
                    'peId': 1,
                    'eqId': 10,
                    'modelo': 'Same model',
                    'sn': 'A',
                    'healthCheckAvailable': true,
                  },
                  {
                    'peId': 2,
                    'eqId': 10,
                    'modelo': 'Same model',
                    'sn': 'B',
                    'healthCheckAvailable': true,
                  },
                  {'peId': 3, 'eqId': 11, 'healthCheckAvailable': false},
                ],
              },
        ),
      );
      final catalog = TicketCatalogService(http.dio);
      expect(
        catalog.endpoint('ticket_create'),
        'https://test.invalid/dashboard/api/ticket_create.php',
      );
      expect((await catalog.sites()).single['csId'], 9);
      final equipment = await catalog.equipment(9, healthOnly: true);
      expect(equipment.map((e) => e['peId']), [1, 2]);
      expect(equipment.map((e) => e['peSN']), ['A', 'B']);
    },
  );

  test(
    'dashboard preserves server meta rather than recalculating action from process',
    () async {
      http.csrfToken = 'csrf';
      http.dio.httpClientAdapter = FakePhp(
        (_) => jsonResponse({
          'success': true,
          'meta': {'abiertos': 1, 'accion': 0, 'curso': 1},
          'tickets': [
            {
              'tiId': 12,
              'tiProceso': 'meet',
              'tiMeetEstado': 'confirmado',
              'requiereAccionCliente': false,
              'csNombre': 'Sede',
              'clNombre': 'Cliente',
            },
          ],
        }),
      );
      final data = await IndexService(dio: http.dio).obtenerTicketsSedes();
      expect(data['meta']['accion'], 0);
      expect(data['sedes'].single['tickets'].single['tiId'], 12);
    },
  );

  test('notification preferences preserve every category in JSON', () async {
    http.csrfToken = 'csrf';
    final adapter = FakePhp((_) => jsonResponse({'success': true}));
    http.dio.httpClientAdapter = adapter;
    await NotificationsService(dio: http.dio).savePreferences(
      const NotificationPreferences(
        mail: false,
        meet: false,
        folio: false,
      ).copyWith(inApp: false),
    );
    expect(adapter.requests.single.data['notifMeet'], false);
    expect(adapter.requests.single.data['notifFolio'], false);
    expect(adapter.requests.single.data['notifInApp'], false);
  });

  test('late session response cannot restore a logged out account', () async {
    final pending = Completer<ResponseBody>();
    final started = Completer<void>();
    http.dio.httpClientAdapter = FakePhp((_) {
      started.complete();
      return pending.future;
    });
    final request = http.refreshSession();
    final failed = expectLater(request, throwsA(isA<DioException>()));
    await started.future;
    await http.clearSession();
    pending.complete(jsonResponse(serverSession));
    await failed;
    expect(await SessionStore.isLogged(), isFalse);
    expect(http.csrfToken, isNull);
  });

  test(
    'simultaneous protected 401 responses trigger logout only once',
    () async {
      var expirations = 0;
      http.onSessionExpired = () => expirations++;
      http.dio.httpClientAdapter = FakePhp(
        (_) => jsonResponse({'success': false}, status: 401),
      );
      await Future.wait(
        List.generate(
          3,
          (_) => expectLater(
            http.dio.get('/me.php'),
            throwsA(isA<DioException>()),
          ),
        ),
      );
      expect(expirations, 1);
    },
  );

  test(
    'invalid credentials retain the server message instead of session expired',
    () async {
      http.dio.httpClientAdapter = FakePhp(
        (_) => jsonResponse({
          'success': false,
          'error': 'Credenciales incorrectas',
        }, status: 401),
      );
      await expectLater(
        http.dio.post('/login.php', data: {}),
        throwsA(
          isA<DioException>().having(
            (e) => e.message,
            'message',
            'Credenciales incorrectas',
          ),
        ),
      );
    },
  );

  for (final visit in [true, false]) {
    for (final internal in [true, false]) {
      test(
        'schedule visit=$visit internal=$internal uses the exact web JSON contract',
        () async {
          http.csrfToken = 'csrf';
          final adapter = FakePhp((_) => jsonResponse({'success': true}));
          http.dio.httpClientAdapter = adapter;
          final starts = List.generate(
            3,
            (i) => DateTime.now().add(Duration(days: i + 2)),
          );
          await ScheduleService(http.dio).propose(
            ticketId: 10,
            visit: visit,
            internal: internal,
            starts: starts,
            minutes: 30,
            platform: 'Google Meet',
            link: 'https://meet.google.com/test',
          );
          final request = adapter.requests.single;
          final expected =
              internal
                  ? 'backend/api/${visit ? 'visita_propose' : 'meet_create'}.php'
                  : 'dashboard/api/${visit ? 'visita' : 'meet'}_create.php';
          expect(request.uri.path, '/$expected');
          expect(request.headers['X-CSRF-Token'], 'csrf');
          expect(request.data['tiId'], 10);
          expect(request.data[internal ? 'opciones' : 'slots'], hasLength(3));
          if (!visit)
            expect(
              request.data[internal ? 'link' : 'enlace'],
              'https://meet.google.com/test',
            );
        },
      );
    }
    test('schedule accept uses the proposal id, visit=$visit', () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp((_) => jsonResponse({'success': true}));
      http.dio.httpClientAdapter = adapter;
      await ScheduleService(http.dio).accept(
        55,
        visit: visit,
        platform: 'Google Meet',
        link: 'https://meet.google.com/test',
      );
      expect(adapter.requests.single.data, {
        visit ? 'vpId' : 'mpId': 55,
        if (!visit) ...{
          'plataforma': 'Google Meet',
          'enlace': 'https://meet.google.com/test',
          'linkDelivery': 'link',
        },
        'csrf_token': 'csrf',
      });
    });
  }

  test('invalid or repeated meeting times never reach PHP', () async {
    final adapter = FakePhp((_) => jsonResponse({'success': true}));
    http.dio.httpClientAdapter = adapter;
    await expectLater(
      ScheduleService(http.dio).propose(
        ticketId: 1,
        visit: false,
        internal: false,
        starts: List.filled(3, DateTime.now().add(const Duration(days: 1))),
        minutes: 30,
      ),
      throwsArgumentError,
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'equipment totals come from full catalog, not six preview rows',
    () async {
      http.dio.httpClientAdapter = FakePhp(
        (r) => jsonResponse(
          r.uri.path.endsWith('mis_equipos_resumen.php')
              ? {
                'success': true,
                'polizas': [
                  {
                    'pcId': 8,
                    'equipos': List.filled(6, {'peId': 1}),
                  },
                ],
              }
              : {
                'success': true,
                'equipos': List.generate(12, (i) => {'peId': i + 1}),
              },
        ),
      );
      final result = await EquiposService(dio: http.dio).resumen();
      expect(result['polizas'].single['total_equipos'], 12);
    },
  );

  test(
    'inactive, expired and not-yet-active policies are never counted as active',
    () {
      final today = DateTime(2026, 9, 8);
      for (final p in [
        {'pcEstatus': 'Inactivo'},
        {'pcEstatus': 'Activo', 'pcFechaFin': '2026-09-07'},
        {'pcEstatus': 'Activo', 'pcFechaInicio': '2026-09-09'},
      ]) {
        expect(EquiposService.isActivePolicy(p, now: today), isFalse);
      }
      expect(
        EquiposService.isActivePolicy({
          'pcEstatus': 'Activo',
          'pcFechaFin': '2026-09-08',
        }, now: today),
        isTrue,
      );
    },
  );

  test(
    'reports use current sheet endpoint, scoped download and local search',
    () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp(
        (_) => jsonResponse({
          'success': true,
          'hojas': [
            {
              'hsId': 1,
              'hsFolio': 'HS-1',
              'clId': 8,
              'csNombre': 'Norte',
              'eqModelo': 'R740',
            },
            {
              'hsId': 2,
              'hsFolio': 'HS-2',
              'clId': 8,
              'csNombre': 'Sur',
              'eqModelo': 'R750',
            },
          ],
        }),
      );
      http.dio.httpClientAdapter = adapter;
      final result = await ReportesService(
        dio: http.dio,
      ).listar(tab: 'HS_T', q: 'r740');
      expect(
        adapter.requests.single.uri.path,
        '/backend/admin/api/hoja_servicio_list.php',
      );
      expect(result['count'], 1);
      expect(
        result['sedes'].single['items'].single['url'],
        'backend/admin/api/hoja_servicio_download.php?hsId=1',
      );
    },
  );

  test('survey and explicit skip send the canonical payload', () async {
    http.csrfToken = 'csrf';
    final adapter = FakePhp((_) => jsonResponse({'success': true}));
    http.dio.httpClientAdapter = adapter;
    final api = SurveyService(http.dio);
    await api.submit(10, rating: 5, comment: ' Bien ');
    expect(adapter.requests.last.data, {
      'tiId': 10,
      'calificacion': 5,
      'comentario': 'Bien',
      'csrf_token': 'csrf',
    });
    expect(adapter.requests.last.uri.path, '/dashboard/api/encuesta_save.php');
    await api.skip(10);
    expect(adapter.requests.last.uri.path, '/dashboard/api/encuesta_skip.php');
    await expectLater(api.submit(10, rating: 0), throwsArgumentError);
    expect(adapter.requests, hasLength(2));
  });

  test(
    'token renewal reuses this device id instead of associating an explicit user',
    () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp((_) => jsonResponse({'success': true}));
      http.dio.httpClientAdapter = adapter;
      final device = DeviceRegistration(http.dio);
      await device.register('first-token-contract-testing-123456789', 'ios');
      await device.register('renewed-token-contract-testing-123456789', 'ios');
      expect(
        adapter.requests.first.data['deviceId'],
        adapter.requests.last.data['deviceId'],
      );
      expect(adapter.requests.last.data.containsKey('usId'), isFalse);
      expect(adapter.requests.last.data['token'], startsWith('renewed'));
    },
  );

  test(
    'equipment outside the authorized catalog never calls legacy detail',
    () async {
      final adapter = FakePhp(
        (_) => jsonResponse({'success': true, 'equipos': []}),
      );
      http.dio.httpClientAdapter = adapter;
      await expectLater(
        EquiposService(dio: http.dio).detalleEquipo(peId: 99, pcId: 8),
        throwsStateError,
      );
      expect(adapter.requests.single.uri.path, '/php/mis_equipos_poliza.php');
    },
  );

  test('site display filter keys stay stable when ticket ordering changes', () {
    final tickets = [
      {'tiId': 1, 'clNombre': 'A', 'czId': 1, 'csNombre': 'Norte'},
      {'tiId': 2, 'clNombre': 'A', 'czId': 1, 'csNombre': 'Sur'},
    ];
    final first =
        IndexService.groupBySite({'tickets': tickets})['sedes'] as List;
    final reversed =
        IndexService.groupBySite({
              'tickets': tickets.reversed.toList(),
            })['sedes']
            as List;
    expect(first.first['viewKey'], reversed.last['viewKey']);
    expect(first.first['csId'], isNull);
  });

  test('avatar uses canonical server paths, never the former LAN host', () {
    expect(
      AppConfig.avatarUrl('img/Usuario/a.webp'),
      'https://mrsos.com.mx/img/Usuario/a.webp',
    );
    expect(AppConfig.mediaUrl('https://external.invalid/secret'), '');
  });
}
