import 'package:flutter/material.dart';
import 'package:mrsos/screens/ticket_detail_screen.dart';
import 'package:mrsos/services/local_notify.dart';

import 'services/app_http.dart';
import 'screens/splash_gate.dart';
import 'widget/mr_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalNotify.init();

  await AppHttp.init(baseUrl: 'https://mrsos.com.mx/php');

  runApp(const MrSosApp());
}

class MrSosApp extends StatelessWidget {
  const MrSosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MRSOS',
      theme: MRTheme.light(),
      home: const SplashGate(),

      // ✅ aquí resolvemos arguments correctamente
      onGenerateRoute: (settings) {
        if (settings.name == '/ticketDetalle') {
          final args =
              (settings.arguments is Map)
                  ? Map<String, dynamic>.from(settings.arguments as Map)
                  : <String, dynamic>{};

          final tiId = (args['tiId'] is int) ? args['tiId'] as int : 0;
          final folio = (args['folio'] ?? '').toString();

          return MaterialPageRoute(
            builder: (_) => TicketDetailScreen(tiId: tiId, folio: folio),
          );
        }

        return null; // usa rutas default
      },
    );
  }
}
