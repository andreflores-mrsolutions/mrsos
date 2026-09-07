import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:mrsos/screens/onboarding_flow_screen.dart';
import '../services/app_http.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import '../widget/MRPrimaryButton.dart';
import '../widget/colors.dart';
import '../services/session_store.dart';

class WelcomeLoginScreen extends StatefulWidget {
  const WelcomeLoginScreen({super.key, this.dio});

  final Dio? dio;

  @override
  State<WelcomeLoginScreen> createState() => _WelcomeLoginScreenState();
}

class _WelcomeLoginScreenState extends State<WelcomeLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = AuthService(
      dio: widget.dio ?? AppHttp.I.dio,
      loginPath: '/login_app.php',
    ); // ✅ tu php real
  }

  static const Color iconPurple = MRSColors.accent;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final r = await _auth.login(
        usId: _userCtrl.text.trim(),
        usPass: _passCtrl.text,
      );

      if (!mounted) return;

      if (!r.success) {
        _snack(
          r.message.isNotEmpty ? r.message : 'Credenciales inválidas',
          isError: true,
        );
        return;
      }

      if (r.forceChangePass || r.onboardingRequired) {
        final u = r.user!;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => OnboardingFlowScreen(
                  user: u,
                  forceChangePass: r.forceChangePass,
                ),
          ),
        );
        return; // <- IMPORTANTÍSIMO
      }

      // aquí ya sigue el flujo normal (guardar sesión / ir a Home)

      if (r.success && r.user != null) {
        final u = r.user!;
        await SessionStore.saveLogin(
          usId: '${u['usId'] ?? ''}',
          userName: '${u['usNombre'] ?? ''}',
          usAPaterno: '${u['usAPaterno'] ?? ''}',
          usAMaterno: '${u['usAMaterno'] ?? ''}',
          usCorreo: '${u['usCorreo'] ?? ''}',
          usTelefono: '${u['usTelefono'] ?? ''}',
          usUsername: '${u['usUsername'] ?? ''}',
          usImagen: u['usImagen']?.toString(),
          ucrRol: '${u['ucrRol'] ?? ''}',
          czId: u['czId'] != null ? int.tryParse('${u['czId']}') : null,
          csId: u['csId'] != null ? int.tryParse('${u['csId']}') : null,
          ucrClId:
              u['ucrClId'] != null ? int.tryParse('${u['ucrClId']}') : null,
        );

        print('=== LOGIN: PERFIL RECIBIDO ===');
        print('usId=${u['usId']}');
        print('usNombre=${u['usNombre']}');
        print('usAPaterno=${u['usAPaterno']}');
        print('usAMaterno=${u['usAMaterno']}');
        print('usCorreo=${u['usCorreo']}');
        print('usTelefono=${u['usTelefono']}');
        print('usUsername=${u['usUsername']}');
        print('usImagen=${u['usImagen']}');
        print('ucrRol=${u['ucrRol']}');
        print('czId=${u['czId']}');
        print('csId=${u['csId']}');
        print('ucrClId=${u['ucrClId']}');
        print('==============================');
        await SessionStore().debugDump(tag: 'AfterSaveLogin');

        // navegar
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => HomeDashboardScreen(
                  usId: _userCtrl.text.trim(),
                  userName: u['usNombre']?.toString() ?? 'Usuario',
                ),
          ),
        );
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: MRSColors.bg,
      body: SafeArea(
        bottom: false,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 24 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          constraints: const BoxConstraints(minHeight: 250),
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                MRSColors.primaryDark,
                                Color(0xFF18367E),
                              ],
                            ),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(34),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Hero(
                                tag: 'mr-logo',
                                child: Image.asset(
                                  'assets/images/MRlogoB.png',
                                  height: 48,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 34),
                              const Text(
                                'Tu operación,\nsiempre en línea.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  height: 1.02,
                                  letterSpacing: -1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tickets, equipos y servicio coordinados desde un solo espacio.',
                                style: TextStyle(
                                  color: Color(0xFFC7D3EF),
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Divider(
                                      color: MRSColors.teal,
                                      thickness: 3,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'ACCESO SEGURO',
                                    style: TextStyle(
                                      color: MRSColors.muted,
                                      letterSpacing: 1.6,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Bienvenido de vuelta',
                                style: TextStyle(
                                  color: MRSColors.text,
                                  fontSize: 30,
                                  height: 1.05,
                                  letterSpacing: -.7,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Inicia sesión para entrar a tu espacio de trabajo.',
                                style: TextStyle(
                                  color: MRSColors.muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _InputCard(
                                label: 'Número de usuario o correo',
                                controller: _userCtrl,
                                icon: Icons.person_outline_rounded,
                                iconBg: iconPurple,
                                keyboardType: TextInputType.emailAddress,
                                validator:
                                    (v) =>
                                        (v ?? '').trim().isEmpty
                                            ? 'Ingresa tu usuario'
                                            : null,
                                onSubmitted:
                                    (_) => FocusScope.of(context).nextFocus(),
                              ),
                              const SizedBox(height: 14),
                              _InputCard(
                                label: 'Contraseña',
                                controller: _passCtrl,
                                icon: Icons.lock_outline_rounded,
                                iconBg: iconPurple,
                                obscureText: _obscure,
                                validator:
                                    (v) =>
                                        (v ?? '').isEmpty
                                            ? 'Ingresa tu contraseña'
                                            : null,
                                suffix: IconButton(
                                  onPressed:
                                      () =>
                                          setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: MRSColors.muted,
                                  ),
                                ),
                                onSubmitted:
                                    (_) => _loading ? null : _doLogin(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              MRPrimaryButton(
                                text:
                                    _loading
                                        ? 'Validando…'
                                        : 'Entrar a MR Support One Service',
                                color: MRSColors.primary,
                                icon: Icons.login_rounded,
                                onPressed: _loading ? null : _doLogin,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '¿Necesitas ayuda? Contacta a soporte',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: MRSColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.label,
    required this.controller,
    required this.icon,
    required this.iconBg,
    required this.validator,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final Color iconBg;
  final String? Function(String?) validator;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final void Function(String)? onSubmitted;

  static const Color ink = MRSColors.text;
  static const Color border = MRSColors.border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: MRSColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconBg, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                onFieldSubmitted: onSubmitted,
                validator: validator,
                style: const TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  labelText: label,
                  labelStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  suffixIcon: suffix,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
