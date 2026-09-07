import 'package:flutter/material.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/reportes_service.dart';
import 'package:mrsos/widget/mr_skeleton.dart';
import 'package:mrsos/widget/colors.dart';
import 'package:mrsos/widget/mr_theme.dart';
import 'package:mrsos/widget/mr_components.dart';

class ReportesTab extends StatefulWidget {
  const ReportesTab({super.key});

  @override
  State<ReportesTab> createState() => _ReportesTabState();
}

class _ReportesTabState extends State<ReportesTab> {
  // ignore: unused_field
  static const pillActive = Color(0xFF0B1B46);

  late final ReportesService _api;

  bool _loading = true;

  String _tab = 'HS_T'; // HS_T | HS_HC | POLIZAS
  String _q = '';
  final _search = TextEditingController();

  // Respuesta
  int _count = 0;
  List<Map<String, dynamic>> _sedes = []; // para HS
  List<Map<String, dynamic>> _polizas = []; // para POLIZAS

  @override
  void initState() {
    super.initState();
    _api = ReportesService(dio: AppHttp.I.dio);
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
      final r = await _api.listar(tab: _tab, q: _q);
      if (!mounted) return;

      if (r['success'] == true) {
        setState(() {
          _count = int.tryParse('${r['count'] ?? 0}') ?? 0;

          if (_tab == 'POLIZAS') {
            _polizas =
                (r['polizas'] is List)
                    ? List<Map<String, dynamic>>.from(r['polizas'])
                    : <Map<String, dynamic>>[];
            _sedes = [];
          } else {
            _sedes =
                (r['sedes'] is List)
                    ? List<Map<String, dynamic>>.from(r['sedes'])
                    : <Map<String, dynamic>>[];
            _polizas = [];
          }
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

  Future<void> _download(String url) async {
    if (url.trim().isEmpty) {
      _toast('Archivo no disponible.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast('URL inválida.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: MRSColors.bg),

        SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                MRPageIntro(
                  eyebrow: 'Documentación de servicio',
                  title: 'Mis documentos',
                  subtitle:
                      'Hojas de servicio y pólizas. Todo tu respaldo, siempre a la mano.',
                  trailing: _Badge(count: _loading ? null : _count),
                ),
                const SizedBox(height: 22),

                MRSearchField(
                  controller: _search,
                  hint: 'Buscar en mis documentos',
                  onSubmitted: (value) {
                    _q = value.trim();
                    _load();
                  },
                  trailing: IconButton(
                    tooltip: 'Buscar documentos',
                    onPressed: () {
                      _q = _search.text.trim();
                      _load();
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  ),
                ),

                const SizedBox(height: 12),

                // Chips: HS-T / HS-HC / Polizas
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _TabChip(
                        text: 'Tickets',
                        active: _tab == 'HS_T',
                        onTap: () {
                          setState(() => _tab = 'HS_T');
                          _load();
                        },
                      ),
                      const SizedBox(width: 10),
                      _TabChip(
                        text: 'Health Checks',
                        active: _tab == 'HS_HC',
                        onTap: () {
                          setState(() => _tab = 'HS_HC');
                          _load();
                        },
                      ),
                      const SizedBox(width: 10),
                      _TabChip(
                        text: 'Pólizas',
                        active: _tab == 'POLIZAS',
                        onTap: () {
                          setState(() => _tab = 'POLIZAS');
                          _load();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (_tab == 'POLIZAS') ..._buildPolizas() else ..._buildHojas(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHojas() {
    if (_loading) {
      return List.generate(
        6,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonBox(height: 66, width: double.infinity, radius: 18),
        ),
      );
    }

    if (_sedes.isEmpty) {
      return const [
        SizedBox(height: 30),
        Center(
          child: Text(
            'No hay hojas para mostrar.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF71809D),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (final s in _sedes) {
      final sedeNombre = '${s['csNombre'] ?? 'Sede'}';
      final items =
          (s['items'] is List)
              ? List<Map<String, dynamic>>.from(s['items'])
              : <Map<String, dynamic>>[];

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            sedeNombre,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF0B1739),
            ),
          ),
        ),
      );

      for (final it in items) {
        final folio = '${it['folio'] ?? ''}';
        final equipo = '${it['equipo'] ?? ''}';
        final url = '${it['url'] ?? ''}';

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DownloadCard(
              title: folio,
              subtitle: equipo,
              onTap: () => _download(url),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildPolizas() {
    if (_loading) {
      return List.generate(
        6,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonBox(height: 66, width: double.infinity, radius: 18),
        ),
      );
    }

    if (_polizas.isEmpty) {
      return const [
        SizedBox(height: 30),
        Center(
          child: Text(
            'No hay pólizas para mostrar.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF71809D),
            ),
          ),
        ),
      ];
    }

    return _polizas.map((p) {
      final ident = '${p['pcIdentificador'] ?? 'Póliza'}';
      final tipo = '${p['pcTipoPoliza'] ?? ''}';
      final url = '${p['url'] ?? ''}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _DownloadCard(
          title: ident,
          subtitle: tipo,
          onTap: () => _download(url),
        ),
      );
    }).toList();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int? count;

  @override
  Widget build(BuildContext context) {
    final txt = count == null ? '' : '${count!}';
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 230, 232, 255),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        txt,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color.fromARGB(255, 50, 77, 230),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.text,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              active
                  ? MRSColors.accent
                  : const Color.fromARGB(255, 230, 232, 255),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : mrPurple,
          ),
        ),
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MRSectionCard(
    padding: EdgeInsets.zero,
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: const MRIconBox(
        icon: Icons.description_outlined,
        color: MRSColors.tealDark,
        background: MRSColors.tealSoft,
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: MRSColors.muted),
        ),
      ),
      trailing: const Icon(
        Icons.file_download_outlined,
        color: MRSColors.accent,
      ),
    ),
  );
}
