import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mrsos/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mrsos/screens/login_screen.dart';
import 'package:mrsos/widget/MRPrimaryButton.dart';
import 'package:mrsos/widget/colors.dart';

import '../services/session_store.dart';
import '../services/app_http.dart';
import 'onboarding_flow_screen.dart';
import 'home_screen.dart';

class WelcomeMRSOSScreen extends StatefulWidget {
  const WelcomeMRSOSScreen({super.key});

  static const Color mrPurple = Color(0xFF3563FF);

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
      final user = await AppHttp.I.refreshSession();
      final usId = '${user['usId']}';
      final userName = '${user['usNombre'] ?? 'Usuario'}';

      if (!mounted) return;

      // ✅ Navega al Home (sin .then)
      if (user['forceChangePass'] == true ||
          '${user['usConfirmado']}'.toLowerCase() == 'no') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => OnboardingFlowScreen(
                  user: user,
                  forceChangePass: user['forceChangePass'] == true,
                ),
          ),
        );
        return;
      }
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeDashboardScreen(usId: usId, userName: userName),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppHttp.friendlyError(error))));
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
    return Scaffold(
      backgroundColor: MRSColors.primaryDark,
      body: Stack(
        children: [
          Positioned(
            right: -170,
            bottom: -160,
            child: Container(
              width: 430,
              height: 430,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x1A8EABFF), width: 2),
              ),
            ),
          ),
          Positioned(
            right: -80,
            bottom: -80,
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x1A8EABFF), width: 2),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xB3071431), Color(0xC818367E)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/MRlogoB.png',
                      height: 52,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(flex: 2),
                    const Row(
                      children: [
                        SizedBox(
                          width: 38,
                          child: Divider(color: Colors.white, thickness: 3),
                        ),
                        SizedBox(width: 11),
                        Text(
                          'SOPORTE EMPRESARIAL',
                          style: TextStyle(
                            color: Color(0xFFD8E1F7),
                            letterSpacing: 1.8,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Tu operación,\n'),
                          TextSpan(
                            text: 'siempre en línea.',
                            style: TextStyle(color: Color(0xFF8EABFF)),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        height: .98,
                        letterSpacing: -1.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Coordina tickets, equipos, visitas y documentación desde un solo espacio diseñado para dar claridad a cada momento del servicio.',
                      style: TextStyle(
                        color: Color(0xFFC2CEE8),
                        fontSize: 16,
                        height: 1.48,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Benefit(text: 'Seguimiento en tiempo real'),
                        SizedBox(height: 10),
                        _Benefit(text: 'Pólizas y activos centralizados'),
                        SizedBox(height: 10),
                        _Benefit(text: 'Atención coordinada'),
                      ],
                    ),
                    const Spacer(flex: 3),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1413A6A2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x334ED9B7)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: Color(0xFF35D39A),
                            size: 10,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Plataforma operativa',
                              style: TextStyle(
                                color: Color(0xFFC2CEE8),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '24/7',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    MRPrimaryButton(
                      text: _loading ? 'Validando…' : '¡Empecemos!',
                      onPressed: _loading ? null : _goNext,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Color(0xFF79A0FF),
          size: 16,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFD2DBEF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
