// import 'package:flutter/material.dart';
// import 'package:local_auth/local_auth.dart';
// import 'package:mrsos/screens/welcome_screen.dart';

// import '../services/session_store.dart';
// import 'login_screen.dart';
// import 'home_screen.dart';

// class SplashGate extends StatefulWidget {
//   const SplashGate({super.key});

//   @override
//   State<SplashGate> createState() => _SplashGateState();
// }

// class _SplashGateState extends State<SplashGate> {
//   final _auth = LocalAuthentication();

//   @override
//   void initState() {
//     super.initState();
//     _go();
//   }

//   Future<void> _go() async {
//     final logged = await SessionStore.isLogged();

//     // 1) Si no hay “login local”, directo a Login
//     if (!logged) {
//       if (!mounted) return;
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (_) => const WelcomeMRSOSScreen()),
//       );
//       return;
//     }

//     // 2) Hay login local => pedir biométrico si el dispositivo soporta
//     final supported = await _auth.isDeviceSupported();
//     final canCheck = await _auth.canCheckBiometrics;

//     bool ok = true;
//     if (supported && canCheck) {
//       ok = await _auth.authenticate(
//         localizedReason: 'Desbloquear MRSOS',
//         options: const AuthenticationOptions(
//           biometricOnly:
//               false, // permite PIN/patrón del sistema si no hay huella
//           stickyAuth: true,
//         ),
//       );
//     }

//     // Si falla biométrico => mandamos a login (sin borrar datos, tú decides)
//     if (!ok) {
//       if (!mounted) return;
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (_) => const WelcomeLoginScreen()),
//       );
//       return;
//     }

//     // 3) Si pasa => Home
//     final usId = (await SessionStore.usId()) ?? '';
//     final userName = (await SessionStore.userName()) ?? 'Usuario';

//     if (!mounted) return;
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(
//         builder: (_) => HomeDashboardScreen(usId: usId, userName: userName),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: SizedBox(
//           width: 28,
//           height: 28,
//           child: CircularProgressIndicator(strokeWidth: 3),
//         ),
//       ),
//     );
//   }
// }
