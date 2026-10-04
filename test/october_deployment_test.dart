import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/services/auth_service.dart';
import 'package:mrsos/services/chat_service.dart';
import 'package:mrsos/services/email_change_service.dart';
import 'package:mrsos/services/schedule_service.dart';
import 'package:mrsos/services/session_store.dart';
import 'package:mrsos/services/ticket_catalog_service.dart';
import 'package:mrsos/screens/access_gate_screen.dart';
import 'package:mrsos/screens/chat_screen.dart';
import 'package:mrsos/screens/legal_screen.dart';
import 'package:mrsos/screens/mfa_screen.dart';
import 'package:mrsos/widget/equipment_picker.dart';
import 'php_contract_test.dart' show FakePhp, jsonResponse, serverSession;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHttp http;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    http = AppHttp.create(baseUrl: 'https://test.invalid/php');
  });

  test(
    'MFA password step is not a user session; verification preserves challenge cookie and CSRF',
    () async {
      var loginCalls = 0;
      final adapter = FakePhp((r) {
        expect(r.uri.path, '/php/login.php');
        loginCalls++;
        return jsonResponse(
          loginCalls == 1
              ? {
                'success': true,
                'mfaRequired': true,
                'expiresIn': 600,
                'emailHint': 'd***@example.invalid',
                'csrfToken': 'challenge-token',
              }
              : {
                'success': true,
                'forceChangePass': false,
                'csrfToken': 'verified-token',
              },
          cookie: true,
        );
      });
      http.dio.httpClientAdapter = adapter;
      final auth = AuthService(dio: http.dio, loginPath: '/login.php');
      final pending = await auth.login(usId: ' name ', usPass: 'secret');
      expect(pending.mfaRequired, true);
      expect(pending.user, isNull);
      expect(await SessionStore.isLogged(), false);
      expect(adapter.requests.length, 1);
      expect(
        Map.fromEntries(
          (adapter.requests.first.data as FormData).fields,
        )['remember'],
        '0',
      );
      final epoch = http.sessionEpoch;
      final verified = await auth.verify('123456');
      expect(verified.success, true);
      expect(verified.mfaRequired, false);
      expect(http.sessionEpoch, epoch);
      expect(http.csrfToken, 'verified-token');
      expect(
        adapter.requests.last.headers['cookie'],
        contains('PHPSESSID=test-session'),
      );
      expect(adapter.requests.last.headers['X-CSRF-Token'], 'challenge-token');
      expect(Map.fromEntries((adapter.requests.last.data as FormData).fields), {
        'action': 'verify',
        'code': '123456',
      });
      expect(
        adapter.requests,
        hasLength(2),
      ); // no me.php during challenge/consumed-code handling
      await expectLater(auth.verify('123456'), throwsStateError);
    },
  );

  test(
    'MFA wrong code preserves challenge, never repeats password or auto-resends',
    () async {
      var count = 0;
      final adapter = FakePhp((r) {
        count++;
        if (count == 1)
          return jsonResponse({
            'success': true,
            'mfaRequired': true,
            'expiresIn': 600,
            'csrfToken': 'c',
          });
        if (count == 2)
          return jsonResponse({
            'success': false,
            'error': 'Código incorrecto.',
          }, status: 422);
        return jsonResponse({'success': true});
      });
      http.dio.httpClientAdapter = adapter;
      final auth = AuthService(dio: http.dio, loginPath: '/login.php');
      await auth.login(usId: 'test', usPass: 'secret', remember: true);
      await expectLater(auth.verify('abc123'), throwsStateError);
      expect(count, 1);
      await expectLater(auth.verify('000000'), throwsA(isA<DioException>()));
      await auth.verify('123456');
      expect(count, 3);
      expect(
        Map.fromEntries(
          (adapter.requests.first.data as FormData).fields,
        )['remember'],
        '1',
      );
      for (final request in adapter.requests.skip(1)) {
        expect(request.headers['X-CSRF-Token'], 'c');
        expect(
          Map.fromEntries(
            (request.data as FormData).fields,
          ).containsKey('usPass'),
          false,
        );
      }
    },
  );

  test(
    'MFA SMTP failure and malformed challenge cannot fall through to me.php',
    () async {
      final auth = AuthService(dio: http.dio, loginPath: '/login.php');
      final failed = FakePhp(
        (_) => jsonResponse({
          'success': false,
          'error': 'Correo no disponible',
        }, status: 503),
      );
      http.dio.httpClientAdapter = failed;
      await expectLater(
        auth.login(usId: 'u', usPass: 'p'),
        throwsA(isA<DioException>()),
      );
      expect(failed.requests, hasLength(1));
      http.dio.httpClientAdapter = FakePhp(
        (_) => jsonResponse({
          'success': true,
          'mfaRequired': true,
          'expiresIn': 600,
        }),
      );
      await expectLater(auth.login(usId: 'u', usPass: 'p'), throwsStateError);
      await expectLater(auth.verify('123456'), throwsStateError);
    },
  );

  test(
    '428 and forced password 403 request access gate without replay or logout',
    () async {
      var gate = 0, logout = 0;
      http.onAccessRequired = () => gate++;
      http.onSessionExpired = () => logout++;
      http.csrfToken = 'csrf';
      var status = 428;
      final adapter = FakePhp(
        (_) => jsonResponse({
          'success': false,
          'error':
              status == 428
                  ? 'Debes revisar y aceptar los documentos del portal.'
                  : 'Debes cambiar tu contraseña antes de continuar.',
        }, status: status),
      );
      http.dio.httpClientAdapter = adapter;
      await expectLater(
        http.dio.post('/legal_test.php', data: {}),
        throwsA(isA<DioException>()),
      );
      status = 403;
      await expectLater(
        http.dio.post('/test.php', data: {}),
        throwsA(isA<DioException>()),
      );
      expect(gate, 2);
      expect(logout, 0);
      expect(adapter.requests.length, 2);
    },
  );

  test(
    'chat sends ticket ID and plain message only; MRV and oversize messages are blocked',
    () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp(
        (r) => jsonResponse({'success': true, 'messages': [], 'chats': []}),
      );
      http.dio.httpClientAdapter = adapter;
      final service = ChatService(http.dio);
      await service.list();
      await service.thread(12);
      await service.send(12, ' Hola <b>equipo</b> ', role: 'CLI');
      expect(adapter.requests[0].uri.path, '/dashboard/api/chats_list.php');
      expect(adapter.requests[1].uri.queryParameters, {'tiId': '12'});
      expect(adapter.requests[2].data, {
        'tiId': 12,
        'message': 'Hola <b>equipo</b>',
        'csrf_token': 'csrf',
      });
      await expectLater(
        service.send(12, 'hola', role: 'MRV'),
        throwsStateError,
      );
      await expectLater(
        service.send(12, '😀' * 2001, role: 'MRA'),
        throwsStateError,
      );
      expect(adapter.requests.length, 3);
      await service.send(12, '😀' * 2000, role: 'MRSA');
      expect(adapter.requests.length, 4);
    },
  );

  test(
    'admin catalogs include client/site scope and never reuse dashboard client catalog',
    () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp(
        (_) => jsonResponse({
          'success': true,
          'sedes': [],
          'equipos': [],
          'clientes': [],
        }),
      );
      http.dio.httpClientAdapter = adapter;
      final service = TicketCatalogService(http.dio);
      await service.clients();
      await service.sites(clientId: 8);
      await service.responsibleUsers(8, 7);
      await service.equipment(7, clientId: 8);
      expect(adapter.requests.map((r) => r.uri.path), [
        '/backend/api/clientes/cliente_list.php',
        '/backend/api/ticket_catalog_sedes.php',
        '/backend/api/ticket_catalog_clientes.php',
        '/backend/api/ticket_catalog_equipos.php',
      ]);
      expect(adapter.requests[2].uri.queryParameters, {
        'clId': '8',
        'csId': '7',
      });
      expect(adapter.requests[3].uri.queryParameters, {
        'clId': '8',
        'csId': '7',
      });
      expect(
        adapter.requests.every((r) => r.headers['X-CSRF-Token'] == 'csrf'),
        true,
      );
    },
  );

  for (final role in ['CLI', 'MRA', 'MRSA']) {
    test('existing chat thread replies match web payload for $role', () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp((_) => jsonResponse({'success': true}));
      http.dio.httpClientAdapter = adapter;
      await ChatService(
        http.dio,
      ).send(12, ' Respuesta ', role: role, activeThreadId: 77);
      expect(
        adapter.requests.single.uri.path,
        '/${role == 'CLI' ? 'dashboard' : 'backend'}/api/help_reply.php',
      );
      expect(adapter.requests.single.data, {
        'taId': 77,
        'tarMensaje': 'Respuesta',
        if (role != 'CLI') 'tarEsInterno': 0,
        'csrf_token': 'csrf',
      });
    });
  }

  test(
    'SN search supports prefix, suffix, case-insensitive substring and preserves peId',
    () {
      final catalog = [
        {'peId': 1, 'eqId': 9, 'peSN': 'ABC-00123-X', 'eqModelo': 'Dell'},
        {'peId': 2, 'eqId': 9, 'peSN': 'zzz-123', 'eqModelo': 'HP'},
        {'peId': 3, 'peSN': null, 'eqModelo': 'Dell'},
      ];
      expect(
        searchEquipment(
          catalog,
          ' abc',
          mode: SerialMatch.startsWith,
        ).single['peId'],
        1,
      );
      expect(
        searchEquipment(
          catalog,
          '123 ',
          mode: SerialMatch.endsWith,
        ).single['peId'],
        2,
      );
      expect(searchEquipment(catalog, '123').map((e) => e['peId']), [1, 2]);
      expect(searchEquipment(catalog, 'DELL').map((e) => e['peId']), [1, 3]);
      expect(searchEquipment(catalog, 'unknown'), isEmpty);
      expect(searchEquipment(catalog, ''), hasLength(3));
    },
  );

  test(
    'email change requires begin + verify; no password in verification payload',
    () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp(
        (_) => jsonResponse({'success': true, 'email': 'new@example.invalid'}),
      );
      http.dio.httpClientAdapter = adapter;
      final service = EmailChangeService(http.dio);
      await service.begin(' new@example.invalid ', 'secret');
      expect(adapter.requests.single.uri.path, '/php/email_change.php');
      expect(adapter.requests.single.data['action'], 'begin');
      final email = await service.verify('123456');
      expect(email, 'new@example.invalid');
      expect(adapter.requests.last.data, {
        'action': 'verify',
        'code': '123456',
        'csrf_token': 'csrf',
      });
      await expectLater(service.verify('12'), throwsStateError);
      expect(adapter.requests.length, 2);
    },
  );

  test(
    'meeting email invitation mode is explicit and unsafe URLs are rejected',
    () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp(
        (_) => jsonResponse({
          'success': true,
          'emailRecipients': ['support@example.invalid'],
        }),
      );
      http.dio.httpClientAdapter = adapter;
      final api = ScheduleService(http.dio);
      final result = await api.accept(
        2,
        visit: false,
        platform: 'Teams',
        delivery: 'email',
      );
      expect(adapter.requests.single.data, {
        'mpId': 2,
        'plataforma': 'Teams',
        'linkDelivery': 'email',
        'enlace': '',
        'csrf_token': 'csrf',
      });
      expect(result['emailRecipients'], ['support@example.invalid']);
      for (final link in [
        'http://example.invalid',
        'javascript:alert(1)',
        'https://u:p@example.invalid',
      ]) {
        await expectLater(
          api.accept(2, visit: false, platform: 'Teams', link: link),
          throwsArgumentError,
        );
      }
      expect(adapter.requests.length, 1);
    },
  );

  testWidgets(
    'consent requires two explicit checks and exact bundled version',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      http.csrfToken = 'csrf';
      final adapter = FakePhp(
        (r) => jsonResponse(
          r.method == 'GET'
              ? {...serverSession, 'legalAccepted': false}
              : {'success': true},
        ),
      );
      http.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        MaterialApp(home: AccessGateScreen(dio: http.dio)),
      );
      await tester.pumpAndSettle();
      final accept = find.widgetWithText(FilledButton, 'Aceptar y continuar');
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      await tester.ensureVisible(find.byType(CheckboxListTile).last);
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pump();
      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      final post = adapter.requests.where((r) => r.method == 'POST').single;
      expect(post.uri.path, '/php/legal_accept.php');
      expect(post.data, {
        'version': portalLegalVersion,
        'terms': true,
        'privacy': true,
        'csrf_token': 'test-csrf',
      });
      expect(
        adapter.requests.every(
          (r) => ['/php/me.php', '/php/legal_accept.php'].contains(r.uri.path),
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      http.dio.httpClientAdapter = FakePhp(
        (_) => jsonResponse({
          ...serverSession,
          'legalAccepted': false,
          'legalVersion': 'future-version',
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: AccessGateScreen(dio: http.dio)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    },
  );

  testWidgets(
    'forced password comes before consent; failed read after POST cannot replay password',
    (tester) async {
      http.csrfToken = 'csrf';
      var committed = false, failRead = true;
      final adapter = FakePhp((r) {
        if (r.method == 'POST') {
          committed = true;
          return jsonResponse({'success': true});
        }
        if (committed && failRead)
          return jsonResponse({'success': false}, status: 503);
        return jsonResponse({
          ...serverSession,
          'legalAccepted': false,
          'forceChangePass': !committed,
        });
      });
      http.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        MaterialApp(home: AccessGateScreen(dio: http.dio)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Actualiza tu contraseña'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'NewPassword123');
      await tester.enterText(find.byType(TextField).last, 'NewPassword123');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar contraseña'), findsNothing);
      failRead = false;
      await tester.tap(find.text('Volver a comprobar acceso'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(
        adapter.requests.firstWhere((r) => r.method == 'POST').uri.path,
        '/php/usuario_password_primera_vez.php',
      );
    },
  );

  testWidgets(
    'MFA screen validates without granting access or persisting code',
    (tester) async {
      final adapter = FakePhp((_) => jsonResponse({'success': true}));
      http.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        MaterialApp(
          home: MfaScreen(
            auth: AuthService(dio: http.dio, loginPath: '/login.php'),
            challenge: LoginResult(
              success: true,
              message: '',
              forceChangePass: false,
              onboardingRequired: false,
              mfaRequired: true,
              expiresIn: 600,
              emailHint: 'd***@example.invalid',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Verificar y continuar'));
      await tester.pump();
      expect(adapter.requests, isEmpty);
      expect(await SessionStore.isLogged(), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'chat MRV is read-only and polling stops while backgrounded or disposed',
    (tester) async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp(
        (r) => jsonResponse(
          r.uri.path.endsWith('/me.php')
              ? {...serverSession, 'rol': 'MRV'}
              : {
                'success': true,
                'messages': [
                  {
                    'id': 'a-1',
                    'authorId': 1,
                    'authorName': 'Soporte',
                    'message': '<b>Texto literal</b>',
                    'createdAt': '2026-10-03T10:00:00-06:00',
                  },
                ],
              },
        ),
      );
      http.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        MaterialApp(home: TicketChatScreen(tiId: 9, dio: http.dio)),
      );
      await tester.pumpAndSettle();
      expect(find.text('<b>Texto literal</b>'), findsOneWidget);
      expect(find.text('Enviar mensaje'), findsNothing);
      final count = adapter.requests.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 40));
      expect(adapter.requests.length, count);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(adapter.requests.length, greaterThan(count));
      await tester.pumpWidget(const SizedBox.shrink());
      final disposedCount = adapter.requests.length;
      await tester.pump(const Duration(seconds: 40));
      expect(adapter.requests.length, disposedCount);
    },
  );

  testWidgets(
    'successful chat POST plus failed refresh never restores the sent draft',
    (tester) async {
      http.csrfToken = 'csrf';
      var sent = false;
      final adapter = FakePhp((r) {
        if (r.method == 'POST') {
          sent = true;
          return jsonResponse({'success': true});
        }
        if (r.uri.path.endsWith('/me.php')) return jsonResponse(serverSession);
        return jsonResponse(
          sent ? {'success': false} : {'success': true, 'messages': []},
          status: sent ? 503 : 200,
        );
      });
      http.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        MaterialApp(home: TicketChatScreen(tiId: 9, dio: http.dio)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Necesito soporte');
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('equipment picker filters and selects actual peId', (
    tester,
  ) async {
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await pickEquipment(context, [
                      {'peId': 1, 'eqModelo': 'Same model', 'peSN': 'ABC-789'},
                      {'peId': 2, 'eqModelo': 'Same model', 'peSN': 'ABC-123'},
                    ]);
                  },
                  child: const Text('Buscar'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '789');
    await tester.pumpAndSettle();
    expect(find.textContaining('ABC-123'), findsNothing);
    await tester.tap(find.textContaining('ABC-789'));
    await tester.pumpAndSettle();
    expect(selected?['peId'], 1);
  });

  testWidgets('legal text bundled offline matches version and is readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalScreen(kind: 'terms', title: 'Términos')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Versión $portalLegalVersion · MR Support One Service'),
      findsOneWidget,
    );
    expect(find.text('Uso del portal de soporte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'uncertain chat send stays blocked until explicit history review',
    (tester) async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp((r) {
        if (r.method == 'POST') {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return jsonResponse(
          r.uri.path.endsWith('/me.php')
              ? serverSession
              : {'success': true, 'messages': []},
        );
      });
      http.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        MaterialApp(home: TicketChatScreen(tiId: 9, dio: http.dio)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Verificar envío');
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar mensaje'),
            )
            .onPressed,
        isNull,
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
      await tester.tap(find.text('Revisar el envío pendiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya aparece'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
