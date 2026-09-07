import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrsos/widget/home_overview.dart';
import 'package:mrsos/widget/mr_theme.dart';

const sampleTickets = [
  {
    'tiId': 1042,
    'folio': 'MR - 1042',
    'eqModelo': 'PowerEdge R740',
    'csNombre': 'Ciudad de México · Corporativo',
    'tiProceso': 'Revisión de logs',
    'tiNivelCriticidad': 1,
  },
  {
    'tiId': 1038,
    'folio': 'MR - 1038',
    'eqModelo': 'ProLiant DL380 Gen10',
    'csNombre': 'Monterrey · Centro de datos',
    'tiProceso': 'Visita programada',
    'tiNivelCriticidad': 2,
  },
];

Widget overview({
  bool loading = false,
  String? error,
  bool empty = false,
  VoidCallback? onTickets,
  VoidCallback? onCreate,
  VoidCallback? onProfile,
  ValueChanged<Map<String, dynamic>>? onTicket,
}) => HomeOverview(
  name: 'Darwin',
  loading: loading,
  error: error,
  openTickets: 8,
  actionCount: 2,
  tickets: empty ? [] : sampleTickets,
  healthChecks:
      empty
          ? []
          : [
            {
              'hcId': 4,
              'csNombre': 'Corporativo CDMX',
              'hcFechaHora': '2026-09-15 10:30:00',
              'equiposCount': 6,
            },
          ],
  sites:
      empty
          ? []
          : [
            {
              'csId': 1,
              'csNombre': 'Corporativo CDMX',
              'tickets': sampleTickets,
            },
          ],
  onTickets: onTickets ?? () {},
  onCreateTicket: onCreate ?? () {},
  onCreateHealth: () {},
  onProfile: onProfile ?? () {},
  onNotifications: () {},
  onTicket: onTicket ?? (_) {},
  onHealth: (_) {},
  onSite: (_) {},
  onRefresh: () async {},
);

Future<void> render(
  WidgetTester tester, {
  required Size size,
  double scale = 1,
  Widget? child,
  GlobalKey? captureKey,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: MRTheme.light(),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home: RepaintBoundary(
        key: captureKey,
        child: Scaffold(body: child ?? overview()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('overview fits ${size.width} at text scale $scale', (
        tester,
      ) async {
        await render(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -1800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('overview preserves primary actions and ticket selection', (
    tester,
  ) async {
    var tickets = 0;
    var create = 0;
    var profile = 0;
    int? selected;
    await render(
      tester,
      size: const Size(390, 844),
      child: overview(
        onTickets: () => tickets++,
        onCreate: () => create++,
        onProfile: () => profile++,
        onTicket: (ticket) => selected = ticket['tiId'] as int,
      ),
    );
    await tester.tap(find.text('Ir a mis tickets'));
    await tester.tap(find.text('Nuevo ticket'));
    await tester.tap(find.byKey(const ValueKey('open-profile')));
    expect(tickets, 1);
    expect(create, 1);
    expect(profile, 1);
    await tester.scrollUntilVisible(find.text('PowerEdge R740'), 250);
    await tester.tap(find.text('PowerEdge R740'));
    expect(selected, 1042);
  });

  testWidgets('empty, loading and failure states are explicit', (tester) async {
    await render(
      tester,
      size: const Size(390, 844),
      child: overview(empty: true),
    );
    await tester.scrollUntilVisible(
      find.text('Sin tickets en seguimiento'),
      200,
    );
    expect(find.text('Sin tickets en seguimiento'), findsOneWidget);
    await render(
      tester,
      size: const Size(390, 844),
      child: overview(error: 'Revisa tu conexión e intenta de nuevo.'),
    );
    await tester.scrollUntilVisible(
      find.text('No pudimos cargar el resumen'),
      200,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await render(
      tester,
      size: const Size(390, 844),
      child: overview(loading: true),
    );
    expect(find.text('—'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('capture design preview with illustrative data', (tester) async {
    final key = GlobalKey();
    await render(tester, size: const Size(390, 844), captureKey: key);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/design/previews/inicio.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
