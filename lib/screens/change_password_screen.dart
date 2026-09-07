import 'package:flutter/material.dart';

import '../services/app_http.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final response = await AppHttp.I.dio.post(
        '/password_change.php',
        data: {
          'currentPassword': _current.text,
          'newPassword': _next.text,
          'confirmPassword': _confirm.text,
        },
      );
      final json =
          response.data is Map
              ? Map<String, dynamic>.from(response.data as Map)
              : <String, dynamic>{};
      if (json['success'] != true) {
        throw StateError(
          '${json['error'] ?? json['message'] ?? 'No se pudo actualizar la contraseña'}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${json['message'] ?? 'Contraseña actualizada'}'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst('Bad state: ', '')
                .replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F5FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF200F4C)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Usa al menos 10 caracteres e incluye letras y números.',
                      style: TextStyle(
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _current,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator:
                        (value) =>
                            (value ?? '').isEmpty
                                ? 'Captura tu contraseña actual'
                                : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _next,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.length < 10 ||
                          !RegExp(r'[A-Za-z]').hasMatch(password) ||
                          !RegExp(r'\d').hasMatch(password)) {
                        return 'Mínimo 10 caracteres, letras y números';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _saving ? null : _save(),
                    decoration: InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                    validator:
                        (value) =>
                            value != _next.text
                                ? 'Las contraseñas no coinciden'
                                : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Guardando…' : 'Actualizar contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}
