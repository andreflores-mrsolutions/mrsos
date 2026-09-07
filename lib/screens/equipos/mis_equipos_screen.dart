import 'package:flutter/material.dart';
import 'package:mrsos/screens/equipos/poliza_equipos_screen.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/services/equipos_service.dart';
import 'package:mrsos/widget/mr_skeleton.dart';
import 'package:mrsos/widget/colors.dart';
import 'package:mrsos/widget/mr_theme.dart';
import 'package:mrsos/widget/mr_components.dart';
import 'equipo_detalle_screen.dart';

class MisEquiposTab extends StatefulWidget {
  const MisEquiposTab({super.key});

  @override
  State<MisEquiposTab> createState() => _MisEquiposTabState();
}

class _MisEquiposTabState extends State<MisEquiposTab> {
  // ignore: unused_field
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  late final EquiposService api;

  bool loading = true;
  Map<String, dynamic> data = {};

  int _tab = 0; // 0: Activa, 1: Vencida

  @override
  void initState() {
    super.initState();
    api = EquiposService(dio: AppHttp.I.dio); // ✅ misma cookie PHPSESSID
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await api.resumen();
      if (!mounted) return;
      setState(() => data = r);
      _ensureValidTab();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List _polizas() => (data['polizas'] is List) ? data['polizas'] : const [];
  int _polizaTotalEquipos(Map<String, dynamic> p) {
    // Backend ideal: total_equipos (PHP) / totalEquipos (legacy)
    final v1 = p['total_equipos'];
    if (v1 is int) return v1;

    final v2 = p['totalEquipos'];
    if (v2 is int) return v2;

    final v3 = p['equiposTotales'];
    if (v3 is int) return v3;

    // Fallback: si viene lista de equipos dentro de la póliza
    final eq = p['equipos'];
    if (eq is List) return eq.length;

    // Último fallback
    return 0;
  }

  bool _isActivePoliza(Map<String, dynamic> p) {
    // 1) flags directos si vienen
    final v1 = p['vigente'];
    if (v1 is int) return v1 == 1;
    if (v1 is bool) return v1;

    final v2 = p['pcVigente'];
    if (v2 is int) return v2 == 1;
    if (v2 is bool) return v2;

    // 2) estados por texto
    final est = ('${p['pcEstado'] ?? p['pcEstatus'] ?? ''}').toLowerCase();
    if (est.contains('venc')) return false;
    if (est.contains('act') || est.contains('vig')) return true;

    // 3) por fecha fin (yyyy-mm-dd)
    final fin = '${p['pcFechaFin'] ?? ''}'.trim();
    if (fin.isNotEmpty) {
      final dt = DateTime.tryParse(fin);
      if (dt != null) {
        final today = DateTime.now();
        final d0 = DateTime(today.year, today.month, today.day);
        final d1 = DateTime(dt.year, dt.month, dt.day);
        return !d1.isBefore(d0);
      }
    }

    // default: activa
    return true;
  }

  bool _hasVencidas() {
    final list = _polizas().map((e) => Map<String, dynamic>.from(e)).toList();

    // cuenta pólizas que realmente tienen equipos visibles
    final visibles = list.where((p) => _polizaTotalEquipos(p) > 0);

    return visibles.any((p) => !_isActivePoliza(p));
  }

  void _ensureValidTab() {
    // si ya no hay vencidas pero estabas parado en "Vencida", regresa a Activa
    if (_tab == 1 && !_hasVencidas()) {
      _tab = 0;
    }
  }

  List<Map<String, dynamic>> _filteredPolizas() {
    final list = _polizas().map((e) => Map<String, dynamic>.from(e)).toList();
    // Regla: si total de equipos visibles es 0, la póliza no se muestra
    final visibles = list.where((p) => _polizaTotalEquipos(p) > 0);

    return visibles.where((p) {
      final act = _isActivePoliza(p);
      return _tab == 0 ? act : !act;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasVencidas = !loading && _hasVencidas();
    final visiblePolizas =
        _polizas()
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .where((p) => _polizaTotalEquipos(p) > 0)
            .toList();
    final totalEquipos = visiblePolizas.fold<int>(
      0,
      (total, p) => total + _polizaTotalEquipos(p),
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
              const MRPageIntro(
                eyebrow: 'Activos bajo cobertura',
                title: 'Mis equipos',
                subtitle:
                    'Consulta equipos asociados a tus pólizas, sedes y números de serie.',
              ),
              const SizedBox(height: 22),
              _EquipmentSummary(
                loading: loading,
                equipos: totalEquipos,
                polizas: visiblePolizas.length,
              ),
              const SizedBox(height: 18),

              _PillsToggle(
                leftText: 'Vigentes',
                rightText: 'Vencidas',
                value: _tab,
                rightEnabled: hasVencidas, // 👈 nuevo
                onChanged: (v) => setState(() => _tab = v),
              ),

              const SizedBox(height: 14),

              if (loading)
                ...List.generate(2, (_) => const _PolizaSectionSkeleton())
              else if (_filteredPolizas().isEmpty)
                const MREmptyState(
                  title: 'No hay equipos para mostrar',
                  message:
                      'Los equipos asociados a tus pólizas aparecerán aquí.',
                  icon: Icons.dns_outlined,
                )
              else
                ..._filteredPolizas().map(
                  (p) => _PolizaSection(
                    p: p,
                    active: _isActivePoliza(p),
                    onVerTodo: () {
                      final pcId = int.tryParse('${p['pcId']}') ?? 0;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => MisEquiposPolizaScreen(
                                pcId: pcId,
                                titulo: 'Póliza ${p['pcIdentificador']}',
                              ),
                        ),
                      );
                    },
                    onTapEquipo: (peId) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MisEquiposDetalleScreen(peId: peId),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipmentSummary extends StatelessWidget {
  const _EquipmentSummary({
    required this.loading,
    required this.equipos,
    required this.polizas,
  });

  final bool loading;
  final int equipos;
  final int polizas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.dns_outlined,
            label: 'Equipos visibles',
            value: loading ? '—' : '$equipos',
            color: MRSColors.accent,
            background: MRSColors.blueSoft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.shield_outlined,
            label: 'Pólizas',
            value: loading ? '—' : '$polizas',
            color: MRSColors.teal,
            background: MRSColors.tealSoft,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return MRSectionCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          MRIconBox(icon: icon, color: color, background: background, size: 42),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  style: const TextStyle(
                    color: MRSColors.muted,
                    fontSize: 9.5,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: MRSColors.text,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillsToggle extends StatelessWidget {
  const _PillsToggle({
    required this.leftText,
    required this.rightText,
    required this.value,
    required this.onChanged,
    this.rightEnabled = true,
  });

  final String leftText;
  final String rightText;
  final int value;
  final ValueChanged<int> onChanged;
  final bool rightEnabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: MRSColors.blueSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pill(
              text: leftText,
              active: value == 0,
              enabled: true,
              onTap: () => onChanged(0),
            ),
            const SizedBox(width: 8),
            _Pill(
              text: rightText,
              active: value == 1,
              enabled: rightEnabled,
              onTap: () {
                if (rightEnabled) onChanged(1);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg =
        active
            ? const Color.fromARGB(255, 50, 77, 230)
            : const Color(0xFFEAF0FF);
    final fg = active ? Colors.white : const Color.fromARGB(255, 50, 77, 230);

    // Disabled: más gris y sin interacción
    final disabledBg = const Color(0xFFE6E6EE);
    final disabledFg = const Color(0xFFB2B1C2);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 118,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? bg : disabledBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: enabled ? fg : disabledFg,
          ),
        ),
      ),
    );
  }
}

class _PolizaSection extends StatelessWidget {
  const _PolizaSection({
    required this.p,
    required this.active,
    required this.onVerTodo,
    required this.onTapEquipo,
  });

  final Map<String, dynamic> p;
  final bool active;
  final VoidCallback onVerTodo;
  final void Function(int peId) onTapEquipo;

  List _equipos() => (p['equipos'] is List) ? p['equipos'] : const [];

  List<Map<String, dynamic>> _ticketsAbiertos() =>
      (p['ticketsAbiertos'] is List)
          ? List<Map<String, dynamic>>.from(p['ticketsAbiertos'])
          : const [];

  List<Map<String, dynamic>> _ticketsDeEquipo(int peId) {
    return _ticketsAbiertos()
        .where((t) => int.tryParse('${t['peId']}') == peId)
        .toList();
  }

  String _policyLabel() {
    final ident =
        (p['pcIdentificador'] ?? p['pcNombre'] ?? p['pcNumero'] ?? '')
            .toString()
            .trim();
    if (ident.isNotEmpty) return 'Póliza $ident';

    final tipo = (p['pcTipoPoliza'] ?? '').toString().trim();
    return tipo.isNotEmpty ? 'Póliza $tipo' : 'Póliza';
  }

  String _formatFecha(String v) {
    final t = v.trim();
    if (t.isEmpty) return '';
    return t; // yyyy-mm-dd
  }

  @override
  Widget build(BuildContext context) {
    final equipos =
        _equipos()
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final endDate = _formatFecha('${p['pcFechaFin'] ?? ''}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MRSectionHeading(
            title: _policyLabel(),
            subtitle:
                endDate.isEmpty
                    ? 'Equipos asociados'
                    : '${active ? 'Cobertura hasta' : 'Venció el'} $endDate',
            action: 'Ver póliza',
            onAction: onVerTodo,
          ),
          ...equipos.map((e) {
            final id = int.tryParse('${e['peId']}') ?? 0;
            final model = '${e['eqModelo'] ?? ''}'.trim();
            final brand = '${e['maNombre'] ?? ''}'.trim();
            final serial = '${e['peSN'] ?? ''}'.trim();
            final site = '${e['csNombre'] ?? ''}'.trim();
            final tickets = _ticketsDeEquipo(id);
            final imageUrl =
                'https://mrsos.com.mx/img/Equipos/${Uri.encodeComponent(brand)}/${Uri.encodeComponent(model)}.png';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: MRSColors.border),
                ),
                child: InkWell(
                  onTap: id == 0 ? null : () => onTapEquipo(id),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MRSColors.soft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (_, _, _) => const Icon(
                                      Icons.dns_outlined,
                                      size: 32,
                                      color: MRSColors.accent,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (brand.isNotEmpty)
                                    Text(
                                      brand.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        letterSpacing: 1.3,
                                        fontWeight: FontWeight.w800,
                                        color: MRSColors.muted,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    model.isEmpty ? 'Equipo' : model,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.4,
                                    ),
                                  ),
                                  if (serial.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      'SN $serial',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: MRSColors.muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: MRSColors.muted,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            MRStatusPill(
                              label:
                                  active
                                      ? 'Con cobertura'
                                      : 'Cobertura vencida',
                              color:
                                  active
                                      ? MRSColors.successText
                                      : MRSColors.warningText,
                              icon: Icons.verified_user_outlined,
                            ),
                            if (tickets.isNotEmpty)
                              MRStatusPill(label: '${tickets.length} tickets'),
                          ],
                        ),
                        if (site.isNotEmpty) ...[
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: MRSColors.muted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  site,
                                  style: const TextStyle(
                                    color: MRSColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PolizaSectionSkeleton extends StatelessWidget {
  const _PolizaSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            SkeletonBox(height: 18, width: 180),
            Spacer(),
            SkeletonBox(height: 14, width: 70),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 430,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, __) {
              return Container(
                width: 330,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Column(
                  children: [
                    SkeletonBox(
                      height: 110,
                      width: double.infinity,
                      radius: 18,
                    ),
                    SizedBox(height: 12),
                    SkeletonBox(height: 20, width: 220),
                    SizedBox(height: 8),
                    SkeletonBox(height: 14, width: 260),
                    SizedBox(height: 14),
                    SkeletonBox(height: 30, width: 160, radius: 999),
                    SizedBox(height: 10),
                    SkeletonBox(height: 30, width: 240, radius: 999),
                    SizedBox(height: 12),
                    SkeletonBox(height: 16, width: 240),
                    SizedBox(height: 10),
                    SkeletonBox(height: 44, width: 200),
                    SizedBox(height: 10),
                    SkeletonBox(height: 16, width: 220),
                    SizedBox(height: 6),
                    SkeletonBox(height: 16, width: 280),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
