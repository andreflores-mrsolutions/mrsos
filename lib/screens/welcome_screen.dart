import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mrsos/screens/login_screen.dart';
import 'package:mrsos/widget/MRPrimaryButton.dart';

import '../services/session_store.dart';
import 'home_screen.dart';

class WelcomeMRSOSScreen extends StatefulWidget {
  const WelcomeMRSOSScreen({super.key});

  static const Color mrPurple = Color(0xFF5830E0);

  @override
  State<WelcomeMRSOSScreen> createState() => _WelcomeMRSOSScreenState();
}

class _WelcomeMRSOSScreenState extends State<WelcomeMRSOSScreen> {
  final _auth = LocalAuthentication();
  bool _loading = false;

  Future<void> _goNext() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final logged = await SessionStore.isLogged();

      // 1) Si NO hay sesión -> Login
      if (!logged) {
        if (!mounted) return;
        _pushToLogin();
        return;
      }

      // 2) Hay sesión: EXIGIR biometría activa
      final sp = await SharedPreferences.getInstance();
      final bioEnabled = sp.getBool('pref_bio') ?? false;

      // Si biometría está DESACTIVADA -> Login (regla nueva)
      if (!bioEnabled) {
        if (!mounted) return;
        _pushToLogin();
        return;
      }

      // 3) Biometría está activa: validar capacidad/permiso
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;

      // Si no hay biometría o permisos -> Login (regla nueva)
      if (!(supported && canCheck)) {
        if (!mounted) return;
        _pushToLogin();
        return;
      }

      // 4) Autenticar
      bool ok = false;
      try {
        ok = await _auth.authenticate(
          localizedReason: 'Confirma tu identidad para entrar a MRSOS',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
      } catch (_) {
        ok = false;
      }

      // Si falla -> Login
      if (!ok) {
        if (!mounted) return;
        _pushToLogin();
        return;
      }

      // 5) OK -> Home
      final usId = (await SessionStore.usId()) ?? '';
      final userName = (await SessionStore.userName()) ?? 'Usuario';

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeDashboardScreen(usId: usId, userName: userName),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pushToLogin() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => const WelcomeLoginScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF4FFFA),
              Color(0xFFFFFBEF),
              Color(0xFFF7F5FF),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.35, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                Expanded(
                  flex: 58,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 320,
                        maxHeight: s.height * 0.42,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 18),
                          Image.asset(
                            'assets/images/default.png',
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 22,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¡Aquí tú tienes\nel control!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4B4759),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 14),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'Soporte, tickets y equipos\nen un solo lugar, MRSolutions\nacompañandote a todos lados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF7A7588),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: MRPrimaryButton(
                      text: _loading ? 'Validando…' : '¡Empecemos!',
                      onPressed: _loading ? () {} : _goNext,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
