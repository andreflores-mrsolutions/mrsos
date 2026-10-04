import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/app_http.dart';
import 'access_gate_screen.dart';

class MfaScreen extends StatefulWidget {
  const MfaScreen({
    super.key,
    required this.auth,
    required this.challenge,
    this.dio,
  });
  final AuthService auth;
  final LoginResult challenge;
  final Dio? dio;
  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _code = TextEditingController();
  late final DateTime _deadline;
  Timer? _timer;
  bool _busy = false;
  String? _error;
  int get _seconds =>
      _deadline.difference(DateTime.now()).inSeconds.clamp(0, 3600);
  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(
      Duration(seconds: widget.challenge.expiresIn),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      if (_seconds == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _seconds == 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.auth.verify(_code.text);
      if (!result.success || result.mfaRequired)
        throw StateError(result.message);
      _code.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AccessGateScreen(dio: widget.dio)),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Verificación por correo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 64),
          const SizedBox(height: 24),
          Text(
            'Confirma que eres tú',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Enviamos un código a ${widget.challenge.emailHint}. No lo compartas con nadie.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autofocus: true,
            enabled: !_busy && _seconds > 0,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Código de seis dígitos',
            ),
            onSubmitted: (_) => _verify(),
          ),
          Text(
            _seconds == 0
                ? 'El código expiró.'
                : 'Vigencia: ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
          ),
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
            onPressed: _busy || _seconds == 0 ? null : _verify,
            child: Text(_busy ? 'Verificando…' : 'Verificar y continuar'),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Volver al acceso para solicitar otro código'),
          ),
          const Text(
            'Si no llega, revisa correo no deseado. Para solicitar otro código vuelve a identificarte; no se reenvía automáticamente.',
          ),
        ],
      ),
    ),
  );
}
