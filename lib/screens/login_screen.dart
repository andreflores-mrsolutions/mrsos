import 'package:flutter/material.dart';
import 'package:mrsos/screens/onboarding_flow_screen.dart';
import '../services/app_http.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import '../widget/MRPrimaryButton.dart';
import '../services/session_store.dart';

class WelcomeLoginScreen extends StatefulWidget {
  const WelcomeLoginScreen({super.key});

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
      dio: AppHttp.I.dio,
      loginPath: '/login_app.php',
    ); // ✅ tu php real
  }

  static const Color subInk = Color(0xFF6B667A);
  static const Color iconPurple = Color.fromARGB(255, 71, 74, 255);

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3F0FF),
              Color(0xFFFFFFFF),
              Color(0xFFF7F6FF),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.40, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  18 + (bottomInset > 0 ? 14 : 0),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 26),
                          Hero(
                            tag: 'mr-logo',
                            child: Image.asset(
                              'assets/images/logo MR.webp',
                              height: 64,
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 18),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Para empezar, debemos de iniciar sesión,\n'
                              'los datos deberán de estar en\n'
                              'tu correo electrónico con el que te contactamos\n'
                              'en MRSOS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.2,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: subInk,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),

                          _InputCard(
                            label: 'Usuario',
                            controller: _userCtrl,
                            icon: Icons.badge_outlined,
                            iconBg: iconPurple,
                            keyboardType: TextInputType.number,
                            validator:
                                (v) =>
                                    (v ?? '').trim().isEmpty
                                        ? 'Ingresa tu usuario'
                                        : null,
                            onSubmitted:
                                (_) => FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 16),

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
                                  () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.black.withOpacity(.45),
                              ),
                            ),
                            onSubmitted: (_) => _loading ? null : _doLogin(),
                          ),

                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                foregroundColor: subInk,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                              ),
                              child: const Text(
                                'Olvidé mi contraseña',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(22, 10, 22, 14 + bottomInset),
          child: MRPrimaryButton(
            text: _loading ? 'Validando…' : 'Iniciar Sesión',
            onPressed: _loading ? () {} : _doLogin,
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

  static const Color ink = Color(0xFF1D1B2A);
  static const Color border = Color(0xFFF0EFF6);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                color: iconBg.withOpacity(0.14),
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
