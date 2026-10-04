import 'package:mrsos/widget/session_image.dart';
import 'package:flutter/material.dart';
import 'client_user_detail_screen.dart';
import '../config/app_config.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/widget/mr_skeleton.dart';
import 'package:mrsos/services/usuarios_service.dart';
import 'package:mrsos/widget/colors.dart';
import 'package:mrsos/widget/mr_theme.dart';
import 'package:mrsos/widget/mr_components.dart';

class UsuariosTab extends StatefulWidget {
  const UsuariosTab({super.key});

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
  late final UsuariosService _api;
  bool _loading = true;
  String? _error;

  final _search = TextEditingController();
  String _q = '';

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
    setState(() {
      _loading = true;
      _error = null;
      _groups = [];
    });
    try {
      final r = await _api.listado(q: _q);
      if (!mounted) return;

      if (r['success'] == true) {
        final sedes =
            (r['sedes'] is List)
                ? List<Map<String, dynamic>>.from(r['sedes'])
                : <Map<String, dynamic>>[];
        setState(() {
          _groups = sedes;
        });
      } else {
        setState(
          () => _error = (r['error'] ?? r['message'] ?? 'Error').toString(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userCount = _groups.fold<int>(
      0,
      (total, group) =>
          total +
          (group['usuarios'] is List ? (group['usuarios'] as List).length : 0),
    );

    return ColoredBox(
      color: MRSColors.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              MRPageIntro(
                eyebrow: 'Control de acceso',
                title: 'Nuestro equipo',
                subtitle:
                    'Consulta los datos y el estado de las personas de tu cuenta.',
                trailing: _UsersCountBadge(
                  count: _loading || _error != null ? null : userCount,
                ),
              ),
              const SizedBox(height: 22),

              MRSearchField(
                controller: _search,
                hint: 'Buscar personas',
                onSubmitted: (value) {
                  _q = value.trim();
                  _load();
                },
              ),

              const SizedBox(height: 14),

              if (_loading)
                ...List.generate(3, (_) => const _GroupSkeleton())
              else if (_error != null)
                MREmptyState(
                  title: 'Consulta no disponible',
                  message: _error!,
                  icon: Icons.lock_outline,
                )
              else if (_groups.isEmpty)
                const MREmptyState(
                  title: 'No encontramos personas',
                  message: 'Prueba con otro nombre.',
                  icon: Icons.people_outline_rounded,
                )
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
        ),
      ),
    );
  }
}

class _UsersCountBadge extends StatelessWidget {
  const _UsersCountBadge({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Text(
        count == null ? '—' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
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
        color: Color(0xFF0B1739),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.u});
  final Map<String, dynamic> u;

  @override
  Widget build(BuildContext context) {
    final name = '${u['nombre'] ?? 'Usuario'}';
    final role = '${u['rol'] ?? ''}';
    final username = '${u['username'] ?? ''}';
    final avatar = AppConfig.avatarUrl(u['avatar'], username: username);
    final initials =
        name
            .trim()
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .take(2)
            .map((s) => s.characters.first)
            .join()
            .toUpperCase();
    return MRSectionCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: MRSColors.blueSoft,
          foregroundImage: SessionImageProvider(avatar),
          onForegroundImageError: (_, _) {},
          child: Text(
            initials,
            style: const TextStyle(
              color: MRSColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        subtitle:
            role.isEmpty
                ? null
                : Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: MRSColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 22,
          color: MRSColors.muted,
        ),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        ClientUserDetailScreen(usId: int.parse('${u['usId']}')),
              ),
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
