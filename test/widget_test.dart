import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mrsos/screens/login_screen.dart';
import 'package:mrsos/screens/welcome_screen.dart';
import 'package:mrsos/widget/colors.dart';
import 'package:mrsos/widget/mr_theme.dart';

void main() {
  testWidgets('portal theme renders the shared page language', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MRTheme.light(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(18),
            child: MRPageIntro(
              eyebrow: 'Centro de operación',
              title: 'Resumen',
              subtitle: 'Lectura ejecutiva del servicio.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('CENTRO DE OPERACIÓN'), findsOneWidget);
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Lectura ejecutiva del servicio.'), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.primary, MRSColors.primary);
    expect(materialApp.theme?.colorScheme.secondary, MRSColors.teal);
    expect(materialApp.theme?.scaffoldBackgroundColor, MRSColors.bg);
  });

  testWidgets('welcome screen fits a mobile viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: MRTheme.light(), home: const WelcomeMRSOSScreen()),
    );

    expect(find.textContaining('Tu operación'), findsOneWidget);
    expect(find.text('¡Empecemos!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login screen fits a mobile viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: MRTheme.light(), home: WelcomeLoginScreen(dio: Dio())),
    );

    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.text('Entrar a MR Support One Service'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
