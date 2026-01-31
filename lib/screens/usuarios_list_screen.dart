import 'package:flutter/material.dart';
import 'package:mrsos/screens/usuario_detail_screen.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/widget/mr_skeleton.dart';
import 'package:mrsos/services/usuarios_service.dart';

class UsuariosTab extends StatefulWidget {
  const UsuariosTab({super.key});

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  late final UsuariosService _api;
  bool _loading = true;

  final _search = TextEditingController();
  String _q = '';

  String _rol = '';
  int _czId = 0;
  int _csId = 0;
  String _notif = ''; // '', '0', '1'

  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _api = UsuariosService(dio: AppHttp.I.dio);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.listado(
        q: _q,
        rol: _rol,
        czId: _czId,
        csId: _csId,
        notif: _notif,
      );
      if (!mounted) return;

      if (r['success'] == true) {
        final sedes =
            (r['sedes'] is List)
                ? List<Map<String, dynamic>>.from(r['sedes'])
                : <Map<String, dynamic>>[];
        setState(() {
          _data = r;
          _groups = sedes;
        });
      } else {
        _toast((r['error'] ?? r['message'] ?? 'Error').toString());
      }
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  List<String> _roles() {
    final f = _data['filters'];
    if (f is Map && f['roles'] is List) {
      return List<String>.from(f['roles']);
    }
    return const [];
  }

  List<Map<String, dynamic>> _zonas() {
    final f = _data['filters'];
    if (f is Map && f['zonas'] is List) {
      return List<Map<String, dynamic>>.from(f['zonas']);
    }
    return const [];
  }

  List<Map<String, dynamic>> _sedes() {
    final f = _data['filters'];
    if (f is Map && f['sedes'] is List) {
      return List<Map<String, dynamic>>.from(f['sedes']);
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF7F4FF), Colors.white],
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
            children: [
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Usuarios Grupos/Sedes',
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F1B2E),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Search bar + menu (como mock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEAF6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _FiltersMenuButton(
                      onPickRol: (v) {
                        setState(() => _rol = v);
                        _load();
                      },
                      onPickZona: (id) {
                        setState(() => _czId = id);
                        _load();
                      },
                      onPickSede: (id) {
                        setState(() => _csId = id);
                        _load();
                      },
                      onPickNotif: (v) {
                        setState(() => _notif = v);
                        _load();
                      },
                      onClear: () {
                        setState(() {
                          _rol = '';
                          _czId = 0;
                          _csId = 0;
                          _notif = '';
                        });
                        _load();
                      },
                      roles: _roles(),
                      zonas: _zonas(),
                      sedes: _sedes(),
                      currentRol: _rol,
                      currentCzId: _czId,
                      currentCsId: _csId,
                      currentNotif: _notif,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Buscar Usuario',
                        ),
                        onSubmitted: (v) {
                          _q = v.trim();
                          _load();
                        },
                      ),
                    ),
                    const Icon(Icons.search_rounded, color: mrPurple),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (_loading)
                ...List.generate(3, (_) => const _GroupSkeleton())
              else ...[
                for (final g in _groups) ...[
                  _GroupHeader(title: (g['titulo'] ?? '').toString()),
                  const SizedBox(height: 10),
                  ...(g['usuarios'] is List
                          ? List<Map<String, dynamic>>.from(g['usuarios'])
                          : const <Map<String, dynamic>>[])
                      .map((u) => _UserCard(u: u))
                      .toList(),
                  const SizedBox(height: 18),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltersMenuButton extends StatelessWidget {
  const _FiltersMenuButton({
    required this.roles,
    required this.zonas,
    required this.sedes,
    required this.currentRol,
    required this.currentCzId,
    required this.currentCsId,
    required this.currentNotif,
    required this.onPickRol,
    required this.onPickZona,
    required this.onPickSede,
    required this.onPickNotif,
    required this.onClear,
  });

  final List<String> roles;
  final List<Map<String, dynamic>> zonas;
  final List<Map<String, dynamic>> sedes;

  final String currentRol;
  final int currentCzId;
  final int currentCsId;
  final String currentNotif;

  final void Function(String) onPickRol;
  final void Function(int) onPickZona;
  final void Function(int) onPickSede;
  final void Function(String) onPickNotif;
  final VoidCallback onClear;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu_rounded, color: mrPurple),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (key) async {
        if (key == 'clear') return onClear();

        // Sub-menús con bottom sheet para que sea igual al mock (simple y usable)
        if (key == 'rol') {
          final v = await _pickString(context, 'Rol', [
            '(Todos)',
            ...roles,
          ], currentRol.isEmpty ? '(Todos)' : currentRol);
          if (v == null) return;
          onPickRol(v == '(Todos)' ? '' : v);
        }

        if (key == 'zona') {
          final items = [
            {'id': 0, 'label': '(Todas)'},
            ...zonas.map(
              (z) => {
                'id': int.tryParse('${z['czId']}') ?? 0,
                'label': '${z['czNombre'] ?? 'Zona'}',
              },
            ),
          ];
          final id = await _pickId(context, 'Zona', items, currentCzId);
          if (id == null) return;
          onPickZona(id);
        }

        if (key == 'sede') {
          final items = [
            {'id': 0, 'label': '(Todas)'},
            ...sedes.map(
              (s) => {
                'id': int.tryParse('${s['csId']}') ?? 0,
                'label': '${s['csNombre'] ?? 'Sede'}',
              },
            ),
          ];
          final id = await _pickId(context, 'Sede', items, currentCsId);
          if (id == null) return;
          onPickSede(id);
        }

        if (key == 'notif') {
          final v = await _pickString(
            context,
            'Notificaciones',
            const ['(Todas)', 'Activadas', 'Desactivadas'],
            currentNotif == '1'
                ? 'Activadas'
                : currentNotif == '0'
                ? 'Desactivadas'
                : '(Todas)',
          );
          if (v == null) return;
          onPickNotif(
            v == 'Activadas'
                ? '1'
                : v == 'Desactivadas'
                ? '0'
                : '',
          );
        }
      },
      itemBuilder:
          (_) => [
            const PopupMenuItem(
              value: 'rol',
              child: _MenuRow(icon: Icons.stars_rounded, text: 'Rol'),
            ),
            const PopupMenuItem(
              value: 'zona',
              child: _MenuRow(icon: Icons.location_on_rounded, text: 'Zona'),
            ),
            const PopupMenuItem(
              value: 'sede',
              child: _MenuRow(icon: Icons.public_rounded, text: 'Sede'),
            ),
            const PopupMenuItem(
              value: 'notif',
              child: _MenuRow(
                icon: Icons.notifications_rounded,
                text: 'Notificaciones',
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'clear',
              child: _MenuRow(
                icon: Icons.refresh_rounded,
                text: 'Limpiar filtros',
              ),
            ),
          ],
    );
  }

  static Future<String?> _pickString(
    BuildContext context,
    String title,
    List<String> items,
    String current,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder:
          (_) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              ...items.map(
                (x) => ListTile(
                  title: Text(
                    x,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing:
                      x == current ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(context, x),
                ),
              ),
            ],
          ),
    );
  }

  static Future<int?> _pickId(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items,
    int current,
  ) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder:
          (_) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              ...items.map((it) {
                final id = it['id'] as int;
                final label = it['label'].toString();
                return ListTile(
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing:
                      id == current ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(context, id),
                );
              }),
            ],
          ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.isEmpty ? 'Sede' : title,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: Color(0xFF1F1B2E),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.u});
  final Map<String, dynamic> u;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    final nombre = (u['nombre'] ?? 'Usuario').toString();
    final rol = (u['rol'] ?? '').toString();
    String avatar = (u['username'] ?? '').toString();
    if (u['avatar'] == '1') {
      avatar = (u['username'] ?? '').toString();
    } else {
      avatar = 'avatar_default';
    }
    print(u['usId']);

    // si tu backend guarda en /img/Usuario/<archivo>
    final avatarUrl =
        avatar.isEmpty
            ? ''
            : 'https://yellow-chicken-910471.hostingersite.com/img/Usuario/$avatar.jpg';
    print(avatarUrl);

    return GestureDetector(
      onTap: () {
        // Acción al tocar la tarjeta del usuario (si es necesario)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminUsuarioDetalleScreen(usId: u['usId']),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color.fromARGB(255, 230, 232, 255),
              backgroundImage:
                  (avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/avatar_default.png')
                          as ImageProvider,
              onBackgroundImageError: (_, __) {
                // No puedes setear aquí directo, así que lo resolvemos con foregroundImage abajo
              },
              child:
                  avatarUrl.isEmpty
                      ? const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF200F4C),
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rol.isEmpty ? '' : rol,
                    style: const TextStyle(
                      color: Color(0xFF6B667A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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

class _GroupSkeleton extends StatelessWidget {
  const _GroupSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonBox(height: 14, width: 180),
        SizedBox(height: 10),
        SkeletonBox(height: 70, width: double.infinity, radius: 18),
        SizedBox(height: 12),
        SkeletonBox(height: 70, width: double.infinity, radius: 18),
        SizedBox(height: 18),
      ],
    );
  }
}
