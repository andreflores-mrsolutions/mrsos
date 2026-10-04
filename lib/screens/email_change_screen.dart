import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_http.dart';
import '../services/email_change_service.dart';

class EmailChangeScreen extends StatefulWidget {
  const EmailChangeScreen({super.key});
  @override
  State<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends State<EmailChangeScreen> {
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _code = TextEditingController();
  late final _api = EmailChangeService(AppHttp.I.dio);
  bool _sent = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_sent) {
        final email = await _api.verify(_code.text);
        _code.clear();
        if (!mounted) return;
        Navigator.pop(context, email);
      } else {
        await _api.begin(_email.text, _password.text);
        _password.clear();
        if (mounted) setState(() => _sent = true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verificar nuevo correo')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Tu correo actual seguirá activo hasta verificar el nuevo. Al confirmar se revocarán los accesos recordados y se enviará un aviso de seguridad al correo anterior.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          enabled: !_sent && !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Nuevo correo'),
        ),
        if (!_sent)
          TextField(
            controller: _password,
            obscureText: true,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Contraseña actual'),
          )
        else ...[
          const SizedBox(height: 16),
          const Text(
            'Revisa el nuevo correo. El código vence en diez minutos y admite hasta cinco intentos.',
          ),
          TextField(
            controller: _code,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Código de seis dígitos',
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? 'Validando…'
                : _sent
                ? 'Verificar y actualizar correo'
                : 'Enviar código al nuevo correo',
          ),
        ),
        if (_sent)
          TextButton(
            onPressed:
                _busy
                    ? null
                    : () => setState(() {
                      _sent = false;
                      _code.clear();
                      _error = null;
                    }),
            child: const Text('Solicitar un nuevo código'),
          ),
      ],
    ),
  );
}
