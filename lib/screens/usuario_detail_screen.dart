import 'package:flutter/material.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:dio/dio.dart';

class AdminUsuarioDetalleScreen extends StatefulWidget {
  const AdminUsuarioDetalleScreen({super.key, required this.usId});
  final int usId;

  @override
  State<AdminUsuarioDetalleScreen> createState() =>
      _AdminUsuarioDetalleScreenState();
}

class _AdminUsuarioDetalleScreenState extends State<AdminUsuarioDetalleScreen> {
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  late final Dio _dio;

  bool _loading = true;

  Map<String, dynamic> u = {};
  List<Map<String, dynamic>> roles = [];
  List<Map<String, dynamic>> zonas = [];
  List<Map<String, dynamic>> sedes = [];

  // campos editables
  String _miRolSesion = '';
  String _nombre = '';
  String _usId = '';
  String _apellidoPaterno = '';
  String _apellidoMaterno = '';
  String _telefono = '';
  String _correo = '';
  String _rol = '';
  String _username = '';
  int _czId = 0;
  int _csId = 0;

  @override
  void initState() {
    super.initState();
    _dio = AppHttp.I.dio;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.post(
        '/adm_usuario_detalle.php',
        // IMPORTANT: el PHP lee usId desde POST (no querystring)
        data: FormData.fromMap({'usId': widget.usId}),
      );

      final data =
          (res.data is Map)
              ? Map<String, dynamic>.from(res.data)
              : <String, dynamic>{};

      if (data['success'] == true) {
        final user = Map<String, dynamic>.from(data['usuario'] ?? {});
        final listas = Map<String, dynamic>.from(data['listas'] ?? {});

        final rRoles =
            (listas['roles'] is List) ? List.from(listas['roles']) : [];
        final rZonas =
            (listas['zonas'] is List)
                ? List<Map<String, dynamic>>.from(listas['zonas'])
                : <Map<String, dynamic>>[];
        final rSedes =
            (listas['sedes'] is List)
                ? List<Map<String, dynamic>>.from(listas['sedes'])
                : <Map<String, dynamic>>[];
        final scope = Map<String, dynamic>.from(data['scope'] ?? {});
        final miRol = (scope['rol'] ?? '').toString();

        setState(() {
          _miRolSesion = miRol;
        });

        setState(() {
          _miRolSesion = miRol;
          u = user;
          roles = rRoles.map((e) => {'rol': e.toString()}).toList();
          zonas = rZonas;
          sedes = rSedes;
          _usId = (user['usId'] ?? '').toString();
          _nombre = (user['nombre'] ?? '').toString();
          _apellidoPaterno = (user['apaterno'] ?? '').toString();
          _apellidoMaterno = (user['amaterno'] ?? '').toString();
          _telefono = (user['telefono'] ?? '').toString();
          _correo = (user['correo'] ?? '').toString();
          _rol = (user['rol'] ?? '').toString();
          _username = (user['username'] ?? '').toString();
          _czId = int.tryParse('${user['czId'] ?? 0}') ?? 0;
          _csId = int.tryParse('${user['csId'] ?? 0}') ?? 0;
          print(_csId);
        });
      } else {
        _toast((data['error'] ?? data['message'] ?? 'Error').toString());
      }
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _esAdminSesion {
    final r = _miRolSesion.toUpperCase();
    return r.contains('ADMIN_GLOBAL') ||
        r.contains('ADMIN_ZONA') ||
        r.contains('ADMIN_SEDE');
  }

  bool get _isAdminZona => _rol.toUpperCase().contains('ADMIN_ZONA');
  // bool get _isAdminSede => _rol.toUpperCase().contains('ADMIN_SEDE');
  bool get _isUsuario => _rol.toUpperCase().contains('USUARIO');
  bool get _isVisor => _rol.toUpperCase().contains('VISOR');
  bool get _requiereSede =>
      _isUsuario || _isVisor; // roles que requieren asociarse a sede/grupo
  bool get _mostrarSedeCard =>
      _requiereSede; // solo mostrar el dropdown si aplica
  bool get _mostrarZonaCard =>
      _isAdminZona || _requiereSede; // solo mostrar zona si aplica

  String _avatarUrl() {
    // El PHP ya devuelve avatarUrl listo para usarse
    final url = (u['avatarUrl'] ?? '').toString().trim();
    if (url.isEmpty) return '';
    // Si viene relativo (../img/..), lo convertimos a absoluto con el baseUrl
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = AppHttp.I.baseUrl.replaceAll(RegExp(r'/*$'), '');
    final rel = url.replaceFirst(RegExp(r'^\.+/'), ''); // quita ../
    return '$base/$rel';
  }

  // fallback: si no existe el avatar, usamos un asset o una imagen default del server
  Widget _avatarWidget() {
    final url = _avatarUrl();
    if (url.isEmpty) {
      return const CircleAvatar(
        radius: 44,
        backgroundColor: Color(0xFFEAE6FF),
        child: Icon(Icons.person_rounded, size: 46, color: mrPurple),
      );
    }

    return CircleAvatar(
      radius: 44,
      backgroundColor: const Color.fromARGB(255, 230, 232, 255),
      child: ClipOval(
        child: Image.network(
          url,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFFEAE6FF),
              child: Icon(Icons.person_rounded, size: 46, color: mrPurple),
            );
          },
        ),
      ),
    );
  }

  Future<void> _editarTexto({
    required String titulo,
    required String valorInicial,
    required ValueChanged<String> onSave,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final c = TextEditingController(text: valorInicial);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0DBF7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                keyboardType: keyboardType,
                decoration: const InputDecoration(
                  hintText: 'Escribe aquí…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 50, 77, 230),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (ok == true) onSave(c.text.trim());
  }

  List<Map<String, dynamic>> get _sedesFiltradasPorZona {
    // Si no estamos mostrando selector de zona, no filtramos por zona
    if (!_mostrarZonaCard) return sedes;

    // Si aún no elige zona, mostramos todas (puedes cambiarlo a [] si quieres forzar elección)
    if (_czId <= 0) return sedes;

    return sedes
        .where((s) => int.tryParse('${s['czId'] ?? 0}') == _czId)
        .toList();
  }

  Future<void> _reloadSedesByZona() async {
    try {
      final res = await _dio.post(
        '/adm_usuario_detalle.php',
        data: FormData.fromMap({
          'usId': widget.usId,
          if (_czId > 0) 'czIdFiltro': _czId,
        }),
      );

      final data =
          (res.data is Map)
              ? Map<String, dynamic>.from(res.data)
              : <String, dynamic>{};

      if (data['success'] == true) {
        final listas = Map<String, dynamic>.from(data['listas'] ?? {});
        final rSedes =
            (listas['sedes'] is List)
                ? List<Map<String, dynamic>>.from(listas['sedes'])
                : <Map<String, dynamic>>[];

        if (mounted) {
          setState(() {
            sedes = rSedes;
          });
        }
      }
    } catch (_) {
      // silencioso: si falla, el filtro local sigue funcionando
    }
  }

  Future<void> _guardarCambios() async {
    try {
      // El PHP adm_usuario_actualizar.php espera JSON en el body.
      // Nombres esperados: usId, nombre, apaterno, amaterno, correo, telefono,
      // username, nivel, sedeId, czId (opcional), newPass, newPass2
      final res = await _dio.post(
        '/adm_usuario_actualizar.php',
        data: {
          'usId': widget.usId,
          'nombre': _nombre,
          'apaterno': _apellidoPaterno,
          'amaterno': _apellidoMaterno,
          'correo': _correo,
          'telefono': _telefono,
          // username no se edita en esta pantalla, pero el backend lo requiere
          'username': _username,
          // en backend se llama "nivel" (rol del cliente)
          'nivel': _rol,
          // en backend se llama "sedeId"
          'sedeId': _csId > 0 ? _csId : null,
          // para ADMIN_ZONA permitimos guardar czId aunque sedeId vaya null
          'czId': _czId > 0 ? _czId : null,
          // no cambiamos password aquí
          'newPass': '',
          'newPass2': '',
        },
      );

      final data =
          (res.data is Map)
              ? Map<String, dynamic>.from(res.data)
              : <String, dynamic>{};
      if (data['success'] == true) {
        _toast('Usuario actualizado');
        _load();
      } else {
        print(data['error']);
        print(data['message']);
        _toast(
          (data['error'] ?? data['message'] ?? 'No se pudo actualizar')
              .toString(),
        );
      }
    } catch (e) {
      print(e);
      _toast('Error: $e');
    }
  }

  Future<void> _resetPassword() async {
    // Este endpoint generará password aleatorio, enviará correo y pondrá usEstatus=NewPassword
    try {
      final res = await _dio.post(
        '/adm_usuario_reset_password.php',
        data: FormData.fromMap({
          'accion': 'reset_password',
          'usId': widget.usId,
        }),
      );

      final data =
          (res.data is Map)
              ? Map<String, dynamic>.from(res.data)
              : <String, dynamic>{};
      if (data['success'] == true) {
        _toast('Se envió una nueva contraseña al correo del usuario');
      } else {
        _toast(
          (data['error'] ?? data['message'] ?? 'No se pudo reestablecer')
              .toString(),
        );
      }
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _cambiarEstatus(String accion) async {
    // accion: desactivar | eliminar
    try {
      final res = await _dio.post(
        '/adm_usuario_eliminar.php',
        data: FormData.fromMap({'accion': accion, 'usId': widget.usId}),
      );

      final data =
          (res.data is Map)
              ? Map<String, dynamic>.from(res.data)
              : <String, dynamic>{};
      if (data['success'] == true) {
        _toast('Actualizado');
        _load();
      } else {
        _toast(
          (data['error'] ?? data['message'] ?? 'No se pudo actualizar')
              .toString(),
        );
      }
    } catch (e) {
      _toast('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Usuarios Grupos/Sedes';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    const SizedBox(height: 6),
                    Center(
                      child: Stack(
                        children: [
                          _avatarWidget(),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 50, 77, 230),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _usId.isEmpty ? 'ID User' : _usId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        _nombre.isEmpty ? 'Usuario' : _nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      icon: Icons.person_rounded,
                      label: 'Nombre del Contacto',
                      value: _nombre,
                      trailingText: 'Editar',
                      onTap:
                          () => _editarTexto(
                            titulo: 'Nombre del Contacto',
                            valorInicial: _nombre,
                            onSave: (v) => setState(() => _nombre = v),
                          ),
                    ),
                    _InfoCard(
                      icon: Icons.person_rounded,
                      label: 'Apellido Paterno del Contacto',
                      value: _apellidoPaterno,
                      trailingText: 'Editar',
                      onTap:
                          () => _editarTexto(
                            titulo: 'Apellido Paterno del Contacto',
                            valorInicial: _apellidoPaterno,
                            onSave: (v) => setState(() => _apellidoPaterno = v),
                          ),
                    ),
                    _InfoCard(
                      icon: Icons.person_rounded,
                      label: 'Apellido Materno del Contacto',
                      value: _apellidoMaterno,
                      trailingText: 'Editar',
                      onTap:
                          () => _editarTexto(
                            titulo: 'Apellido Materno del Contacto',
                            valorInicial: _apellidoMaterno,
                            onSave: (v) => setState(() => _apellidoMaterno = v),
                          ),
                    ),
                    _InfoCard(
                      icon: Icons.phone_rounded,
                      label: 'Número del contacto',
                      value: _telefono,
                      trailingText: 'Editar',
                      onTap:
                          () => _editarTexto(
                            titulo: 'Número del contacto',
                            valorInicial: _telefono,
                            keyboardType: TextInputType.phone,
                            onSave: (v) => setState(() => _telefono = v),
                          ),
                    ),
                    _InfoCard(
                      icon: Icons.mail_rounded,
                      label: 'Correo Electrónico',
                      value: _correo,
                      trailingText: 'Editar',
                      onTap:
                          () => _editarTexto(
                            titulo: 'Correo Electrónico',
                            valorInicial: _correo,
                            keyboardType: TextInputType.emailAddress,
                            onSave: (v) => setState(() => _correo = v),
                          ),
                    ),

                    // Si es Admin Zona: dropdown de ZONA
                    if (_mostrarZonaCard)
                      _DropdownCard(
                        icon: Icons.public_rounded,
                        label: 'Zona',
                        valueText:
                            _czId > 0
                                ? (zonas.firstWhere(
                                      (z) =>
                                          int.tryParse('${z['czId'] ?? 0}') ==
                                          _czId,
                                      orElse: () => {'czNombre': 'Seleccionar'},
                                    )['czNombre'] ??
                                    'Seleccionar')
                                : 'Seleccionar',
                        items:
                            zonas
                                .map(
                                  (z) => DropdownMenuItem<int>(
                                    value:
                                        int.tryParse('${z['czId'] ?? 0}') ?? 0,
                                    child: Text('${z['czNombre'] ?? ''}'),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          setState(() {
                            _czId = (v ?? 0);
                            final ok = _sedesFiltradasPorZona.any(
                              (s) => int.tryParse('${s['csId'] ?? 0}') == _csId,
                            );
                            if (!ok) _csId = 0;
                            _reloadSedesByZona();
                          });
                        },
                      ),
                    // Sede dropdown
                    if (_mostrarSedeCard)
                      _DropdownCard(
                        icon: Icons.apartment_rounded,
                        label: 'Grupos/Sedes',
                        valueText:
                            _csId > 0
                                ? (_sedesFiltradasPorZona.firstWhere(
                                      (s) =>
                                          int.tryParse('${s['csId'] ?? 0}') ==
                                          _csId,
                                      orElse: () => {'csNombre': 'Seleccionar'},
                                    )['csNombre'] ??
                                    'Seleccionar')
                                : 'Seleccionar',
                        items:
                            _sedesFiltradasPorZona
                                .map(
                                  (s) => DropdownMenuItem<int>(
                                    value:
                                        int.tryParse('${s['csId'] ?? 0}') ?? 0,
                                    child: Text(
                                      '${s['clNombre'] ?? ''}${(s['clNombre'] != null) ? ' · ' : ''}${s['csNombre'] ?? ''}'
                                          .trim(),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _csId = (v ?? 0)),
                      ),
                    // Rol dropdown
                    _DropdownCard(
                      icon: Icons.badge_rounded,
                      label: 'Rango',
                      valueText:
                          _rol.isEmpty
                              ? 'Seleccionar'
                              : _rol.replaceAll('_', ' '),
                      items:
                          roles
                              .map(
                                (r) => DropdownMenuItem<String>(
                                  value: (r['rol'] ?? '').toString(),
                                  child: Text(
                                    (r['rol'] ?? '').toString().replaceAll(
                                      '_',
                                      ' ',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        setState(() {
                          _rol = (v ?? '');
                          if (!_isAdminZona) _czId = 0;
                        });
                      },
                    ),

                    const SizedBox(height: 10),
                    if (_esAdminSesion) ...[
                      _ActionButton(
                        text: 'Guardar cambios',
                        bg: const Color.fromARGB(255, 50, 77, 230),
                        fg: Colors.white,
                        onTap: _guardarCambios,
                      ),
                      const SizedBox(height: 10),

                      _ActionButton(
                        text: 'Reestablecer contraseña',
                        bg: const Color.fromARGB(255, 230, 232, 255),
                        fg: mrPurple,
                        onTap: _resetPassword,
                      ),
                      const SizedBox(height: 10),

                      _ActionButton(
                        text: 'Desactivar Cuenta',
                        bg: const Color(0xFFF2FF63),
                        fg: Colors.black,
                        onTap: () => _cambiarEstatus('desactivar'),
                      ),
                      const SizedBox(height: 10),

                      _ActionButton(
                        text: 'Eliminar Cuenta',
                        bg: const Color(0xFFFF6B6B),
                        fg: Colors.white,
                        onTap: () => _cambiarEstatus('eliminar'),
                      ),
                    ] else ...[
                      // Opcional: mostrar un texto en vez de nada
                      Center(
                        child: Text(
                          _nombre.isEmpty ? 'Usuario' : _nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B667A),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailingText,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String trailingText;
  final VoidCallback onTap;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 230, 232, 255),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: mrPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B667A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value.isEmpty ? '—' : value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B667A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownCard<T> extends StatelessWidget {
  const _DropdownCard({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.items,
    required this.onChanged,
    this.value,
  });

  final IconData icon;
  final String label;
  final String valueText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 230, 232, 255),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: mrPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B667A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      isExpanded: true,
                      value: value,
                      hint: Text(
                        valueText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      items: items,
                      onChanged: onChanged,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: mrPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.text,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String text;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
