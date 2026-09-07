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
  if (path.endsWith('obtener_equipo_poliza.php'))
    return {
      'success': true,
      'equipos': [deviceFixture],
    };
  if (path.endsWith('detalle_ticket.php'))
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
  if (path.endsWith('reportes_listar.php'))
    return {
      'success': true,
      'count': 1,
      'sedes': [
        {
          'csNombre': 'Corporativo Ciudad de México',
          'items': [
            {
              'folio': 'HS - 1042',
              'equipo': 'PowerEdge R740 · Revisión técnica',
              'url': 'https://example.invalid/fixture.pdf',
            },
          ],
        },
      ],
      'polizas': [],
    };
  if (path.endsWith('usuarios_listado.php'))
    return {
      'success': true,
      'filters': {},
      'sedes': [
        {
          'titulo': 'Corporativo Ciudad de México',
          'usuarios': [
            {
              'usId': 1,
              'nombre': 'Ana Martínez',
              'rol': 'Administrador',
              'avatar': '0',
            },
            {
              'usId': 2,
              'nombre': 'Diego Hernández',
              'rol': 'Contacto técnico',
              'avatar': '0',
            },
          ],
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
    (
      'nuevo-ticket',
      () =>
          const CreateTicketScreen(baseUrl: 'https://ui-fixtures.invalid/php'),
    ),
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
          requests.any((r) => r.path.endsWith('/usuarios_listado.php')),
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
    expect(requests.last.queryParameters['q'], 'HS 1042');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
