import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/app_http.dart';
import '../services/usuarios_service.dart';
import '../widget/session_image.dart';

class ClientUserDetailScreen extends StatefulWidget {
  const ClientUserDetailScreen({super.key, required this.usId});
  final int usId;
  @override
  State<ClientUserDetailScreen> createState() => _ClientUserDetailScreenState();
}

class _ClientUserDetailScreenState extends State<ClientUserDetailScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final key in [
      'usNombre',
      'usAPaterno',
      'usAMaterno',
      'usCorreo',
      'usTelefono',
      'usUsername',
      'usPass',
    ])
      key: TextEditingController(),
  };
  late final _api = UsuariosService(dio: AppHttp.I.dio);
  Map<String, dynamic> _user = {};
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _api.detalle(widget.usId);
      if (!mounted) return;
      setState(() {
        _user = user;
        for (final key in _fields.keys) {
          _fields[key]!.text = '${user[key] ?? ''}';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _api.actualizar(widget.usId, {
        for (final e in _fields.entries) e.key: e.value.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Datos guardados.')));
      await _load();
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(Object e) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppHttp.friendlyError(e))));
  }

  Future<void> _toggle() async {
    final target = _user['usEstatus'] == 'Activo' ? 'Inactivo' : 'Activo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              target == 'Activo'
                  ? '¿Activar esta cuenta?'
                  : '¿Desactivar esta cuenta?',
            ),
            content: const Text(
              'Este cambio afecta el acceso de la persona a MRSoS.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _api.cambiarEstatus(widget.usId, target);
      if (mounted) await _load();
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    bool required = true,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_saving,
      keyboardType: keyboard,
      obscureText: key == 'usPass',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (raw) {
        final value = (raw ?? '').trim();
        if (required && value.isEmpty) return 'Campo requerido';
        if (key == 'usTelefono' && !RegExp(r'^\d+$').hasMatch(value))
          return 'Usa solamente dígitos';
        if (key == 'usCorreo' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value))
          return 'Correo inválido';
        if (key == 'usPass' &&
            value.isNotEmpty &&
            (value.length < 10 ||
                !RegExp(r'[A-Za-z]').hasMatch(value) ||
                !RegExp(r'\d').hasMatch(value))) {
          return 'Mínimo 10 caracteres, letras y números';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Persona de tu cuenta')),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
            : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      foregroundImage: SessionImageProvider(
                        AppConfig.avatarUrl(
                          _user['usImagen'],
                          username: '${_user['usUsername'] ?? ''}',
                        ),
                      ),
                      onForegroundImageError: (_, _) {},
                      child: const Icon(Icons.person, size: 36),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Estatus: ${_user['usEstatus'] ?? 'No disponible'}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _field('usNombre', 'Nombre'),
                  _field('usAPaterno', 'Apellido paterno'),
                  _field('usAMaterno', 'Apellido materno', required: false),
                  _field(
                    'usCorreo',
                    'Correo',
                    keyboard: TextInputType.emailAddress,
                  ),
                  _field(
                    'usTelefono',
                    'Teléfono',
                    keyboard: TextInputType.phone,
                  ),
                  _field('usUsername', 'Nombre de usuario'),
                  _field(
                    'usPass',
                    'Nueva contraseña temporal (opcional)',
                    required: false,
                  ),
                  const Text(
                    'Si cambias la contraseña, la persona deberá renovarla al entrar. Los roles por sede no se modifican desde este formulario.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _saving ? null : _toggle,
                    child: Text(
                      _user['usEstatus'] == 'Activo'
                          ? 'Desactivar cuenta'
                          : 'Activar cuenta',
                    ),
                  ),
                ],
              ),
            ),
  );
}
