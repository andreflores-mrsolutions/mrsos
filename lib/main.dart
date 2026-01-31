import 'package:flutter/material.dart';
import 'services/app_http.dart';
import 'screens/splash_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppHttp.init(
    baseUrl: 'https://yellow-chicken-910471.hostingersite.com/php',
  ); // tu host real
  runApp(const MrSosApp());
}

class MrSosApp extends StatelessWidget {
  const MrSosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MRSOS',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'TTNorms',
      ),
      home: const SplashGate(), // ✅ aquí se decide biométrico/login/home
    );
  }
}
