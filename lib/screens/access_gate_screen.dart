import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/app_http.dart';
import '../services/session_store.dart';
import '../services/push_service.dart';
import '../services/document_service.dart';
import 'home_screen.dart';
import 'legal_screen.dart';
import 'login_screen.dart';

/// No operational screen or device registration is allowed before these gates.
class AccessGateScreen extends StatefulWidget {
  const AccessGateScreen({super.key, this.dio});
  final Dio? dio;
  @override
  State<AccessGateScreen> createState() => _AccessGateScreenState();
}

class _AccessGateScreenState extends State<AccessGateScreen> {
  late final Dio _dio = widget.dio ?? AppHttp.I.dio;
  Map<String, dynamic>? _user;
  bool _busy = false, _terms = false, _privacy = false;
  String? _error;
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  @override
  void initState() {
    super.initState();
    PushService.I.lock();
    _load();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _readAndContinue();
    } catch (e) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readAndContinue() async {
    final user = AppHttp.jsonMap((await _dio.get('/me.php')).data);
    if (user['success'] != true || user['usId'] == null)
      throw StateError('No autenticado.');
    if (!mounted) return;
    setState(() => _user = user);
    if (user['forceChangePass'] == true || user['legalAccepted'] != true)
      return;
    await SessionStore.saveServerSession(user);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (_) => HomeDashboardScreen(
              usId: '${user['usId']}',
              userName: '${user['usNombre'] ?? 'Usuario'}',
            ),
      ),
      (_) => false,
    );
  }

  Future<void> _submit() async {
    if (_busy || _user == null) return;
    final changePassword = _user!['forceChangePass'] == true;
    if (changePassword) {
      if (_password.text.length < 10 ||
          !RegExp(r'[a-zA-Z]').hasMatch(_password.text) ||
          !RegExp(r'[0-9]').hasMatch(_password.text) ||
          _password.text != _confirmation.text) {
        setState(
          () =>
              _error =
                  'Usa al menos 10 caracteres, letras y números. Ambas contraseñas deben coincidir.',
        );
        return;
      }
    } else if (!_terms ||
        !_privacy ||
        _user!['legalVersion'] != portalLegalVersion) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _dio.post(
        changePassword
            ? '/usuario_password_primera_vez.php'
            : '/legal_accept.php',
        data:
            changePassword
                ? {'password': _password.text, 'password2': _confirmation.text}
                : {
                  'version': portalLegalVersion,
                  'terms': true,
                  'privacy': true,
                },
      );
      final result = AppHttp.jsonMap(response.data);
      if (result['success'] != true) throw StateError(AppHttp.message(result));
      _password.clear();
      _confirmation.clear();
      if (mounted) setState(() => _user = null);
      // Re-read even after a successful mutation; never replay the POST.
      await _readAndContinue();
    } catch (e) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _dio.post('/logout.php');
    } catch (_) {}
    await AppHttp.I.clearSession();
    await PushService.I.sessionExpired();
    try {
      await DocumentService.clearCache();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final forced = _user?['forceChangePass'] == true;
    final versionMatches = _user?['legalVersion'] == portalLegalVersion;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Acceso seguro'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              forced ? Icons.password_rounded : Icons.verified_user_outlined,
              size: 52,
            ),
            const SizedBox(height: 20),
            Text(
              forced ? 'Actualiza tu contraseña' : 'Antes de continuar',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (_user != null && forced) ...[
              const Text(
                'Tu cuenta requiere una contraseña nueva antes de usar los servicios.',
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
              ),
              TextField(
                controller: _confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                ),
              ),
            ] else if (_user != null) ...[
              const Text(
                'Revisa los documentos del portal. Esta aceptación no autoriza publicidad.',
              ),
              const LegalLinks(),
              if (!versionMatches)
                const Text(
                  'El servidor publicó documentos nuevos. Actualiza la app para revisarlos y continuar.',
                )
              else ...[
                const Text('Versión $portalLegalVersion'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _terms,
                  onChanged:
                      _busy ? null : (v) => setState(() => _terms = v == true),
                  title: const Text(
                    'He leído y acepto los términos y condiciones de uso del portal.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _privacy,
                  onChanged:
                      _busy
                          ? null
                          : (v) => setState(() => _privacy = v == true),
                  title: const Text(
                    'He leído el aviso de privacidad y autorizo el tratamiento descrito para operar y atender mis servicios. Esto no autoriza publicidad.',
                  ),
                ),
              ],
              const Text(
                'No aceptar no modifica los derechos u obligaciones de tu contrato. Contacta a soporte para atención por los medios acordados.',
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
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_user != null)
                FilledButton(
                  onPressed:
                      forced || (versionMatches && _terms && _privacy)
                          ? _submit
                          : null,
                  child: Text(
                    forced ? 'Guardar contraseña' : 'Aceptar y continuar',
                  ),
                ),
              TextButton(
                onPressed: _load,
                child: const Text('Volver a comprobar acceso'),
              ),
              TextButton(onPressed: _leave, child: const Text('Cerrar sesión')),
            ],
          ],
        ),
      ),
    );
  }
}
