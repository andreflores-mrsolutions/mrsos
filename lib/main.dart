import 'package:flutter/material.dart';
import 'package:mrsos/screens/ticket_detail_screen.dart';
import 'services/document_service.dart';
import 'config/app_config.dart';
import 'services/push_service.dart';
import 'screens/notifications_screen.dart';
import 'screens/login_screen.dart';
import 'screens/access_gate_screen.dart';

import 'services/app_http.dart';
import 'screens/splash_gate.dart';
import 'widget/mr_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppHttp.init(baseUrl: AppConfig.apiBaseUrl);
  var expiring = false;
  var gating = false;
  AppHttp.I.onAccessRequired = () {
    if (gating || expiring) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    gating = true;
    PushService.I.lock();
    navigator
        .pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AccessGateScreen()),
          (_) => false,
        )
        .whenComplete(() => gating = false);
  };
  AppHttp.I.onSessionExpired = () async {
    if (expiring) return;
    expiring = true;
    PushService.I.lock();
    try {
      await AppHttp.I.clearSession();
      await PushService.I.sessionExpired();
      try {
        await DocumentService.clearCache();
      } catch (_) {}
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeLoginScreen()),
        (_) => false,
      );
    } finally {
      expiring = false;
    }
  };
  PushService.I.onOpenInbox = () {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  };
  await PushService.I.initialize();

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

          final tiId = int.tryParse('${args['tiId']}') ?? 0;
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
