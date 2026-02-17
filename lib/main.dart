import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mrsos/screens/ticket_detail_screen.dart';
import 'package:mrsos/services/local_notify.dart';
import 'package:mrsos/services/push_router.dart';

import 'firebase_options.dart';
import 'services/app_http.dart';
import 'screens/splash_gate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotify.init();

  FirebaseMessaging.onMessage.listen((msg) {
    final title = msg.notification?.title ?? 'MR SOS';
    final body = msg.notification?.body ?? '';
    if (body.isNotEmpty) {
      LocalNotify.show(title: title, body: body);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    PushRouter.capture(msg);
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    PushRouter.capture(initialMessage);
  }

  await AppHttp.init(baseUrl: 'http://192.168.3.7/php');

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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'TTNorms',
      ),
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
