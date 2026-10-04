import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mrsos/config/app_config.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/services/equipos_service.dart';
import 'package:mrsos/services/log_guides_service.dart';
import 'package:mrsos/services/onboarding_service.dart';
import 'package:mrsos/services/usuarios_service.dart';
import 'package:mrsos/widget/session_image.dart';
import 'php_contract_test.dart' show FakePhp, jsonResponse, serverSession;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHttp http;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    http = AppHttp.create(baseUrl: 'https://test.invalid/php');
  });

  test(
    'JSON and multipart contain current CSRF without modifying caller data',
    () async {
      http.csrfToken = 'fresh-token';
      final adapter = FakePhp((_) => jsonResponse({'success': true}));
      http.dio.httpClientAdapter = adapter;
      final json = {'value': 7, 'csrf_token': 'stale'};
      final form = FormData.fromMap({
        'csrf_token': 'stale',
        'logs': MultipartFile.fromString('test-log', filename: 'test.log'),
      });
      await http.dio.post('/guardar_preferencias.php', data: json);
      await http.dio.post('/actualizar_perfil.php', data: form);
      expect(adapter.requests.first.data, {
        'value': 7,
        'csrf_token': 'fresh-token',
      });
      expect(json['csrf_token'], 'stale');
      final submitted = adapter.requests.last.data as FormData;
      expect(
        submitted.fields.where((e) => e.key == 'csrf_token').single.value,
        'fresh-token',
      );
      expect(submitted.files.single.value.filename, 'test.log');
      expect(form.isFinalized, false);
      expect(
        adapter.requests.every(
          (r) => r.headers['X-CSRF-Token'] == 'fresh-token',
        ),
        true,
      );
    },
  );

  test('serialized JSON and urlencoded payloads also carry CSRF', () async {
    http.csrfToken = 'fresh-token';
    final adapter = FakePhp((_) => jsonResponse({'success': true}));
    http.dio.httpClientAdapter = adapter;
    await http.dio.post(
      '/guardar_preferencias.php',
      data: '{"theme":"dark"}',
      options: Options(contentType: 'application/json'),
    );
    await http.dio.post(
      '/guardar_preferencias.php',
      data: 'theme=dark',
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    expect(
      jsonDecode(adapter.requests.first.data)['csrf_token'],
      'fresh-token',
    );
    expect(
      Uri.splitQueryString(adapter.requests.last.data)['csrf_token'],
      'fresh-token',
    );
  });

  test('backend GET uses CSRF and the PHP session rotated by me.php', () async {
    await http.cookies.saveFromResponse(Uri.parse('https://test.invalid/'), [
      Cookie('PHPSESSID', 'old')..path = '/',
    ]);
    final adapter = FakePhp(
      (r) =>
          r.uri.path.endsWith('me.php')
              ? jsonResponse(serverSession, cookie: true)
              : jsonResponse({'success': true}),
    );
    http.dio.httpClientAdapter = adapter;
    await http.dio.get(
      'https://test.invalid/backend/api/clientes/usuario_cli_list.php',
      queryParameters: {'clId': 8},
    );
    expect(adapter.requests.last.headers['X-CSRF-Token'], 'test-csrf');
    expect(
      adapter.requests.last.headers['cookie'],
      contains('PHPSESSID=test-session'),
    );
    expect(
      adapter.requests.last.headers['cookie'],
      isNot(contains('PHPSESSID=old')),
    );
  });

  test(
    'protected media uses cookie jar and cache keys are isolated by session',
    () async {
      final adapter = FakePhp(
        (r) =>
            r.uri.path.endsWith('me.php')
                ? jsonResponse(serverSession, cookie: true)
                : ResponseBody.fromBytes(
                  [137, 80, 78, 71],
                  200,
                  headers: {
                    'content-type': ['image/png'],
                  },
                ),
      );
      http.dio.httpClientAdapter = adapter;
      await http.refreshSession();
      final image = SessionImageProvider('../img/Usuario/test.png', http: http);
      expect(await image.fetchBytes(), [137, 80, 78, 71]);
      expect(adapter.requests.last.uri.path, '/img/Usuario/test.png');
      expect(
        adapter.requests.last.headers['cookie'],
        contains('PHPSESSID=test-session'),
      );
      expect(adapter.requests.last.headers['Cache-Control'], 'no-store');
      await http.clearSession();
      expect(
        SessionImageProvider('img/Usuario/test.png', http: http),
        isNot(image),
      );
      final before = adapter.requests.length;
      await expectLater(image.fetchBytes(), throwsStateError);
      expect(adapter.requests.length, before);
    },
  );

  test(
    'media rejects external URLs, private files and SVG before sending',
    () async {
      final adapter = FakePhp((_) => throw StateError('No request expected'));
      http.dio.httpClientAdapter = adapter;
      for (final path in [
        'https://external.invalid/img/Usuario/a.png',
        '//external.invalid/img/a.png',
        'img/Usuario/a.svg',
        'uploads/a.png',
        'img/Polizas/a.png',
        'mrsos-private/img/Usuario/a.png',
        'img/Usuario/%252e%252e/a.png',
        'https://user:pass@test.invalid/img/Usuario/a.png',
      ]) {
        await expectLater(
          SessionImageProvider(path, http: http).fetchBytes(),
          throwsStateError,
          reason: path,
        );
      }
      expect(adapter.requests, isEmpty);
    },
  );

  test('legacy web media paths normalize without changing API route names', () {
    for (final path in [
      '../img/Usuario/a.png',
      './img/Usuario/a.png',
      '/react-app/img/Usuario/a.png',
      'Usuario/a.png',
      'img/img/Usuario/a.png',
    ]) {
      expect(
        AppConfig.mediaUrl(path),
        'https://mrsos.com.mx/img/Usuario/a.png',
      );
    }
    expect(
      AppConfig.mediaUrl('dashboard/api/log_guides_download.php?lgId=2'),
      'https://mrsos.com.mx/dashboard/api/log_guides_download.php?lgId=2',
    );
    expect(
      AppConfig.mediaUrl('img/Equipos/Dell/Power%20Edge.png'),
      'https://mrsos.com.mx/img/Equipos/Dell/Power%20Edge.png',
    );
    expect(AppConfig.mediaUrl('img/Usuario/%00a.png'), '');
  });

  test(
    'stale success and failure responses cannot restore old cookies',
    () async {
      for (final status in [200, 401]) {
        final started = Completer<void>();
        final finish = Completer<ResponseBody>();
        final adapter = FakePhp((_) {
          started.complete();
          return finish.future;
        });
        http.dio.httpClientAdapter = adapter;
        final request = http.dio.get('/me.php');
        final expectation = expectLater(request, throwsA(isA<DioException>()));
        await started.future;
        await http.clearSession();
        finish.complete(
          jsonResponse(
            status == 200 ? serverSession : {'error': 'Expired'},
            status: status,
            cookie: true,
          ),
        );
        await expectation;
        expect(
          await http.cookies.loadForRequest(Uri.parse('https://test.invalid/')),
          isEmpty,
        );
      }
    },
  );

  test('equipment detail uses only the server-scoped public catalog', () async {
    final adapter = FakePhp(
      (r) => jsonResponse({
        'success': true,
        'prefix': 'MR',
        'equipos': [
          {'peId': 12, 'eqModelo': 'R740', 'peSN': 'SERIAL'},
        ],
      }),
    );
    http.dio.httpClientAdapter = adapter;
    final result = await EquiposService(
      dio: http.dio,
    ).detalleEquipo(peId: 12, pcId: 8);
    expect(result['equipo']['peId'], 12);
    expect(result['ticketsAvailable'], false);
    expect(adapter.requests.single.uri.path, '/php/mis_equipos_poliza.php');
  });

  test(
    'user directory derives client scope from me and uses published backend',
    () async {
      final adapter = FakePhp(
        (r) =>
            r.uri.path.endsWith('me.php')
                ? jsonResponse(serverSession)
                : jsonResponse({
                  'success': true,
                  'usuarios': [
                    {
                      'usId': 12,
                      'usNombre': 'Ana',
                      'usAPaterno': 'López',
                      'usEstatus': 'Activo',
                      'usImagen': 'img/Usuario/ana.webp',
                    },
                  ],
                }),
      );
      http.dio.httpClientAdapter = adapter;
      final service = UsuariosService(dio: http.dio);
      final result = await service.listado(q: 'ana');
      expect(result['sedes'].single['usuarios'].single['nombre'], 'Ana López');
      expect(
        adapter.requests.last.uri.path,
        '/backend/api/clientes/usuario_cli_list.php',
      );
      expect(adapter.requests.last.queryParameters['clId'], 8);
      expect(adapter.requests.last.headers['X-CSRF-Token'], 'test-csrf');
      await service.actualizar(12, {
        'usNombre': 'Ana',
        'clId': 999,
        'usId': 999,
      });
      expect(
        adapter.requests.last.uri.path,
        '/backend/api/clientes/usuario_cli_update.php',
      );
      expect(adapter.requests.last.data['clId'], 8);
      expect(adapter.requests.last.data['usId'], 12);
      expect(adapter.requests.last.data['csrf_token'], 'test-csrf');
      await service.cambiarEstatus(12, 'Inactivo');
      expect(
        adapter.requests.last.uri.path,
        '/backend/api/clientes/usuario_cli_toggle.php',
      );
      expect(adapter.requests.last.data['to'], 'Inactivo');
    },
  );

  test(
    'non-admin directory access does not fall back to a legacy endpoint',
    () async {
      final adapter = FakePhp(
        (_) => jsonResponse({...serverSession, 'ucrRol': 'VISOR'}),
      );
      http.dio.httpClientAdapter = adapter;
      await expectLater(
        UsuariosService(dio: http.dio).listado(),
        throwsStateError,
      );
      expect(adapter.requests.single.uri.path, '/php/me.php');
    },
  );

  test(
    'onboarding retry after partial save does not reset password twice',
    () async {
      var force = true, profileFails = true;
      final adapter = FakePhp((r) {
        if (r.uri.path.endsWith('me.php'))
          return jsonResponse({...serverSession, 'forceChangePass': force});
        if (r.uri.path.endsWith('usuario_password_primera_vez.php')) {
          force = false;
          return jsonResponse({'success': true});
        }
        if (r.uri.path.endsWith('actualizar_perfil.php')) {
          return jsonResponse(
            profileFails ? {'error': 'Profile failed'} : {'success': true},
          );
        }
        throw StateError('Unexpected endpoint: ${r.uri.path}');
      });
      http.dio.httpClientAdapter = adapter;
      final service = OnboardingService(dio: http.dio);
      Future<void> save() => service.save(
        usId: 42,
        usNombre: 'Ana',
        usAPaterno: 'López',
        usAMaterno: '',
        usCorreo: 'ana@example.invalid',
        usTelefono: '5550001111',
        usUsername: 'ana',
        pass1: 'testpass1234',
        pass2: 'testpass1234',
      );
      await expectLater(save(), throwsA(isA<DioException>()));
      profileFails = false;
      await save();
      final changes = adapter.requests.where(
        (r) => r.uri.path.endsWith('usuario_password_primera_vez.php'),
      );
      expect(changes.length, 1);
      expect(changes.single.data, {
        'password': 'testpass1234',
        'password2': 'testpass1234',
        'csrf_token': 'test-csrf',
      });
    },
  );

  test(
    'log guides use the public authenticated API and equipment filter',
    () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp(
        (_) => jsonResponse({
          'success': true,
          'guides': [
            {'lgId': 1, 'title': 'Guía'},
          ],
        }),
      );
      http.dio.httpClientAdapter = adapter;
      expect(
        (await LogGuidesService(http.dio).list(peId: 12)).single['lgId'],
        1,
      );
      expect(
        adapter.requests.single.uri.path,
        '/dashboard/api/log_guides_list.php',
      );
      expect(adapter.requests.single.queryParameters['peId'], 12);
    },
  );

  test(
    'gateway plain-text failures are actionable and never replay mutations',
    () async {
      http.csrfToken = 'csrf';
      for (final status in [404, 503]) {
        final adapter = FakePhp(
          (_) => ResponseBody.fromString('Unavailable', status),
        );
        http.dio.httpClientAdapter = adapter;
        await expectLater(
          http.dio.post('/guardar_preferencias.php', data: {'theme': 'dark'}),
          throwsA(
            isA<DioException>().having(
              (e) => e.message,
              'message',
              contains(
                status == 404 ? 'no está publicada' : 'no está disponible',
              ),
            ),
          ),
        );
        expect(adapter.requests.length, 1);
      }
    },
  );
}
