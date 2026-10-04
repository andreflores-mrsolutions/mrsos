import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/screens/home_screen.dart';
import 'package:mrsos/screens/createticket_screen.dart';
import 'package:mrsos/screens/createhealth_screen.dart';
import 'package:mrsos/screens/ticket_detail_screen.dart';
import 'package:mrsos/screens/user_profile_screen.dart';
import 'package:mrsos/screens/schedule_screen.dart';
import 'package:mrsos/screens/survey_screen.dart';
import 'package:mrsos/screens/client_user_detail_screen.dart';
import 'package:mrsos/screens/log_guides_screen.dart';
import 'package:mrsos/screens/chat_screen.dart';
import 'package:mrsos/screens/email_change_screen.dart';
import 'package:mrsos/screens/meeting_confirmation_screen.dart';
import 'package:mrsos/screens/access_gate_screen.dart';
import 'package:mrsos/screens/mfa_screen.dart';
import 'package:mrsos/services/auth_service.dart';
import 'package:mrsos/widget/mr_theme.dart';

const deviceFixture = {
  'eqId': 10,
  'peId': 10,
  'eqModelo': 'PowerEdge R740',
  'maNombre': 'Dell',
  'peSN': 'DEMO-SN-1042',
  'csId': 1,
  'csNombre': 'Corporativo Ciudad de México',
};
const ticketFixture = {
  ...deviceFixture,
  'tiId': 1042,
  'folio': 'MR - 1042',
  'tiNivelCriticidad': '1',
  'tiProceso': 'logs',
  'tiTipoTicket': 'Servicio',
};
final requests = <RequestOptions>[];

Map<String, dynamic> responseFor(RequestOptions options) {
  final path = options.uri.path;
  if (RegExp(
    r'/(getIndexData|usuarios_listado|equipo_detalle|detalle_health_check|guardar_onboarding_app|adm_usuario_.*)\.php$',
  ).hasMatch(path)) {
    throw StateError('The new gateway does not publish $path');
  }
  if (path.endsWith('/me.php'))
    return {
      'success': true,
      'usId': 42,
      'usNombre': 'Darwin',
      'usAPaterno': 'Martínez',
      'usCorreo': 'demo@example.invalid',
      'usTelefono': '555 010 2040',
      'usUsername': 'darwin.demo',
      'rol': 'CLI',
      'ucrRol': 'ADMIN_SEDE',
      'csrfToken': 'fixture-csrf',
      'legalAccepted': true,
      'legalVersion': '2026-10-02.1',
      'clId': 8,
      'csId': 1,
      'preferences': {'notifInApp': true, 'notifMail': true},
    };
  if (path.endsWith('/meet_get.php') || path.endsWith('/visita_get.php'))
    return {
      'success': true,
      'autorTipo': 'ingeniero',
      'meet': {'estado': 'pendiente'},
      'visita': {'tiVisitaEstado': 'pendiente'},
      'accepted': null,
      'propuestas': [
        {
          'mpId': 50,
          'vpId': 60,
          'mpInicio': '2027-01-10 10:00:00',
          'mpFin': '2027-01-10 10:30:00',
          'mpEstado': 'pendiente',
          'vpEstado': 'pendiente',
        },
      ],
    };
  if (path.endsWith('ticket_catalog_sedes.php')) {
    return {
      'success': true,
      'sedes': [
        {
          'csId': 1,
          'csNombre': deviceFixture['csNombre'],
          'healthCheckAvailable': true,
        },
      ],
    };
  }
  if (path.endsWith('ticket_catalog_equipos.php')) {
    return {
      'success': true,
      'equipos': [
        {
          ...deviceFixture,
          'modelo': deviceFixture['eqModelo'],
          'marca': deviceFixture['maNombre'],
          'sn': deviceFixture['peSN'],
          'healthCheckAvailable': true,
        },
      ],
    };
  }
  if (path.endsWith('tickets_list.php')) {
    return {
      'success': true,
      'meta': {'abiertos': 8, 'accion': 1, 'curso': 2},
      'tickets': [
        {
          ...ticketFixture,
          'tiEstatus': 'Abierto',
          'requiereAccionCliente': true,
        },
      ],
    };
  }
  if (path.endsWith('mis_equipos_poliza.php')) {
    return {
      'success': true,
      'total_equipos': 1,
      'equipos': [deviceFixture],
    };
  }
  if (path.endsWith('obtener_equipo_poliza.php'))
    return {
      'success': true,
      'equipos': [deviceFixture],
    };
  if (path.endsWith('ticket_detail.php'))
    return {
      'success': true,
      'ticket': {
        ...ticketFixture,
        'tiDescripcion':
            'Revisión de rendimiento solicitada por el equipo técnico.',
        'tiFechaCreacion': '2026-09-07 10:30:00',
      },
    };
  if (path.endsWith('getIndexData.php'))
    return {
      'ticketsAbiertos': 8,
      'tickets': [ticketFixture],
      'ticketsEnProgreso': [ticketFixture],
      'healthChecks': [],
    };
  if (path.endsWith('obtener_tickets_sedes.php'))
    return {
      'success': true,
      'sedes': [
        {
          'csId': 1,
          'csNombre': 'Corporativo Ciudad de México',
          'clNombre': 'MR',
          'tickets': [ticketFixture],
        },
      ],
    };
  if (path.endsWith('mis_equipos_resumen.php'))
    return {
      'success': true,
      'polizas': [
        {
          'pcId': 8,
          'pcIdentificador': 'MR-2026',
          'vigente': 1,
          'pcFechaFin': '2027-12-31',
          'total_equipos': 1,
          'equipos': [deviceFixture],
          'ticketsAbiertos': [ticketFixture],
        },
        {
          'pcId': 9,
          'pcIdentificador': 'MR-2024',
          'vigente': 0,
          'pcFechaFin': '2024-12-31',
          'total_equipos': 1,
          'equipos': [deviceFixture],
          'ticketsAbiertos': [],
        },
      ],
    };
  if (path.endsWith('hoja_servicio_list.php'))
    return {
      'success': true,
      'total': 1,
      'hojas': [
        {
          'hsId': 1042,
          'hsFolio': 'HS 1042',
          'clId': 8,
          'clNombre': 'MR',
          'csNombre': 'Corporativo Ciudad de México',
          'eqModelo': 'PowerEdge R740',
          'downloadUrl':
              'backend/admin/api/hoja_servicio_download.php?hsId=1042',
        },
      ],
    };
  if (path.endsWith('usuario_cli_list.php'))
    return {
      'success': true,
      'usuarios': [
        {
          'usId': 1,
          'usNombre': 'Ana',
          'usAPaterno': 'Martínez',
          'usEstatus': 'Activo',
          'usImagen': '0',
        },
        {
          'usId': 2,
          'usNombre': 'Diego',
          'usAPaterno': 'Hernández',
          'usEstatus': 'Activo',
          'usImagen': '0',
        },
      ],
    };
  return {'success': true};
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_DESIGN')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/design/previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
  });

  setUp(() async {
    requests.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
    await AppHttp.init(baseUrl: 'https://ui-fixtures.invalid/php');
    AppHttp.I.dio.interceptors.clear();
    AppHttp.I.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: responseFor(options),
            ),
          );
        },
      ),
    );
  });

  for (final entry in <(String, Widget Function())>[
    ('mensajes', () => const ChatsScreen()),
    ('chat-ticket', () => const TicketChatScreen(tiId: 1042, folio: 'MR-1042')),
    ('verificar-correo', () => const EmailChangeScreen()),
    ('confirmar-reunion', () => const MeetingConfirmationScreen(proposal: {})),
    (
      'codigo-acceso',
      () => MfaScreen(
        auth: AuthService(dio: AppHttp.I.dio, loginPath: '/login.php'),
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
    (
      'consentimiento',
      () {
        final dio = Dio(
          BaseOptions(baseUrl: 'https://ui-fixtures.invalid/php'),
        );
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest:
                (options, handler) => handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {...responseFor(options), 'legalAccepted': false},
                  ),
                ),
          ),
        );
        return AccessGateScreen(dio: dio);
      },
    ),
    (
      'nuevo-ticket',
      () =>
          const CreateTicketScreen(baseUrl: 'https://ui-fixtures.invalid/php'),
    ),
    ('reunion', () => const ScheduleScreen(ticketId: 1042, visit: false)),
    ('visita', () => const ScheduleScreen(ticketId: 1042, visit: true)),
    ('encuesta', () => const SurveyScreen(ticketId: 1042)),
    ('guías', () => const LogGuidesScreen()),
    ('persona', () => const ClientUserDetailScreen(usId: 1)),
    (
      'health-check',
      () => const HealthCheckScreen(baseUrl: 'https://ui-fixtures.invalid/php'),
    ),
    (
      'detalle-ticket',
      () => const TicketDetailScreen(tiId: 1042, folio: 'MR - 1042'),
    ),
    (
      'perfil',
      () => const UserProfileScreen(baseUrl: 'https://ui-fixtures.invalid/php'),
    ),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('${entry.$1} content fits at scale $scale', (tester) async {
        SharedPreferences.setMockInitialValues({
          'mrs_usRol': 'CLI',
          'mrs_usNombre': 'Darwin',
          'mrs_usAPaterno': 'Martínez',
          'mrs_usCorreo': 'demo@example.invalid',
          'mrs_usTelefono': '555 010 2040',
          'mrs_usUsername': 'darwin.demo',
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/local_auth'),
              (call) async =>
                  call.method == 'getAvailableBiometrics' ? <String>[] : false,
            );
        final size = Size(scale == 1 ? 390 : 320, 844);
        await tester.binding.setSurfaceSize(size);
        tester.view.devicePixelRatio = 1;
        final key = GlobalKey();
        addTearDown(() async {
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: MRTheme.light(),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: RepaintBoundary(key: key, child: entry.$2()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, key, entry.$1);
        for (var i = 0; i < 4; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final role in ['CLI', 'MRA']) {
    testWidgets('ticket creation sends the scoped $role contract', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(480, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      AppHttp.I.dio.interceptors.clear();
      AppHttp.I.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final path = options.uri.path;
            final data =
                path.endsWith('/me.php')
                    ? {...responseFor(options), 'rol': role}
                    : path.endsWith('/cliente_list.php')
                    ? {
                      'success': true,
                      'clientes': [
                        {'clId': 8, 'clNombre': 'Cliente autorizado'},
                      ],
                    }
                    : path.endsWith('/ticket_catalog_sedes.php')
                    ? {
                      'success': true,
                      'sedes': [
                        {'csId': 7, 'csNombre': 'Sede autorizada'},
                      ],
                    }
                    : path.endsWith('/ticket_catalog_clientes.php')
                    ? {
                      'success': true,
                      'clientes': [
                        {
                          'usId': 99,
                          'nombre': 'Responsable autorizado',
                          'correo': 'responsible@example.invalid',
                          'telefono': '5555555555',
                        },
                      ],
                    }
                    : path.endsWith('/ticket_catalog_equipos.php')
                    ? {
                      'success': true,
                      'equipos': [
                        {
                          'peId': 12,
                          'eqId': 10,
                          'modelo': 'R740',
                          'sn': 'SN-321',
                        },
                      ],
                    }
                    : path.endsWith('/ticket_create.php')
                    ? {'success': true, 'tiId': 200}
                    : responseFor(options);
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: data),
            );
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => const CreateTicketScreen(
                                  baseUrl: 'https://ui-fixtures.invalid/php',
                                ),
                          ),
                        ),
                    child: const Text('Abrir creación'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir creación'));
      await tester.pumpAndSettle();
      if (role == 'MRA') {
        await tester.tap(find.byType(DropdownButton<int>).at(0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliente autorizado').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<int>).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sede autorizada').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<int>).at(2));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Responsable autorizado').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Buscar y seleccionar equipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('R740'));
      await tester.pumpAndSettle();
      final description = find.byWidgetPredicate(
        (w) => w is TextField && w.maxLines == 5,
      );
      await tester.ensureVisible(description);
      await tester.enterText(description, 'Incidente de prueba local');
      await tester.ensureVisible(find.text('Crear Ticket'));
      await tester.tap(find.text('Crear Ticket'));
      await tester.pumpAndSettle();
      final post =
          requests
              .where((r) => r.uri.path.endsWith('/ticket_create.php'))
              .single;
      expect(
        post.uri.path,
        '/${role == 'CLI' ? 'dashboard' : 'backend'}/api/ticket_create.php',
      );
      expect(post.data['peId'], 12);
      expect(post.data['eqId'], 10);
      expect(post.data['csId'], 7);
      expect(post.data.containsKey('usId'), false);
      if (role == 'MRA') {
        expect(post.data['clId'], 8);
        expect(post.data['usIdCliente'], 99);
        expect(post.data['tiCorreoContacto'], 'responsible@example.invalid');
      } else {
        expect(post.data.containsKey('usIdCliente'), false);
        expect(post.data.containsKey('clId'), false);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 740), const Size(390, 844)]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('main tabs fit ${size.width} at scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        tester.view.devicePixelRatio = 1;
        final key = GlobalKey();
        addTearDown(() async {
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: MRTheme.light(),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: RepaintBoundary(
              key: key,
              child: const HomeDashboardScreen(
                usId: 'demo',
                userName: 'Darwin',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width == 390 && scale == 1)
          await capture(tester, key, 'inicio-navegacion');

        for (final entry in [
          (1, 'tickets'),
          (2, 'equipos'),
          (3, 'documentos'),
          (4, 'personas'),
        ]) {
          await tester.tap(find.byType(NavigationDestination).at(entry.$1));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: entry.$2);
          if (size.width == 390 && scale == 1)
            await capture(tester, key, entry.$2);
          final list = find.byType(ListView).hitTestable().first;
          await tester.drag(list, const Offset(0, -450));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.$2} scrolled',
          );
        }
        expect(
          requests.any((r) => r.path.endsWith('/mis_equipos_resumen.php')),
          isTrue,
        );
        expect(
          requests.any((r) => r.path.endsWith('/usuario_cli_list.php')),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('document search submits the entered query', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MRTheme.light(),
        home: const HomeDashboardScreen(usId: 'demo', userName: 'Darwin'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'HS 1042');
    await tester.tap(find.byTooltip('Buscar documentos'));
    await tester.pumpAndSettle();
    expect(requests.last.uri.path, '/backend/admin/api/hoja_servicio_list.php');
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'HS 1042'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
