import 'package:flutter/material.dart';
import 'package:mrsos/screens/equipos/poliza_equipos_screen.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/services/equipos_service.dart';
import 'package:mrsos/widget/mr_skeleton.dart';
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

    return RefreshIndicator(
      onRefresh: _load,
      child: Stack(
        children: [
          // Fondo suave como tu mock
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
              const SizedBox(height: 36),
              Row(
                children: [
                  const Icon(
                    Icons.article_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  const Center(
                    child: Text(
                      'Mis equipos',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F1B2E),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _PillsToggle(
                leftText: 'Activa',
                rightText: 'Vencida',
                value: _tab,
                rightEnabled: hasVencidas, // 👈 nuevo
                onChanged: (v) => setState(() => _tab = v),
              ),

              const SizedBox(height: 14),

              if (loading)
                ...List.generate(2, (_) => const _PolizaSectionSkeleton())
              else
                ..._filteredPolizas().map(
                  (p) => _PolizaSection(
                    p: p,
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
          color: const Color.fromARGB(255, 232, 234, 255),
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
            : const Color(0xFFEDE8FF);
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
    required this.onVerTodo,
    required this.onTapEquipo,
  });

  final Map<String, dynamic> p;
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
    final prefix = p['clienteNombre'] ?? '';
    final equipos =
        _equipos().map((e) => Map<String, dynamic>.from(e)).toList();

    final tipoPol = '${p['pcTipoPoliza'] ?? ''}'.trim();

    final policyIdent = (p['pcIdentificador'] ?? '').toString().trim();
    final chipPoliza =
        policyIdent.isNotEmpty ? 'Póliza $policyIdent' : _policyLabel();

    final fi = _formatFecha('${p['pcFechaInicio'] ?? ''}');
    final ff = _formatFecha('${p['pcFechaFin'] ?? ''}');
    final venceTxt = ff.isNotEmpty ? ff : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado: “Póliza B 6162” + Ver todo
        Row(
          children: [
            Expanded(
              child: Text(
                _policyLabel(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1B2E),
                ),
              ),
            ),
            TextButton(
              onPressed: onVerTodo,
              child: const Text(
                'Ver todo',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color.fromARGB(255, 50, 77, 230),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ✅ LISTA HORIZONTAL (una card grande por equipo)
        SizedBox(
          height: 460, // ajusta si quieres más/menos alto
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: equipos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final e = equipos[i];
              final peId = int.tryParse('${e['peId']}') ?? 0;

              final modelo = '${e['eqModelo'] ?? ''}'.trim();
              final sn = '${e['peSN'] ?? ''}'.trim();
              final marca = '${e['maNombre'] ?? ''}'.trim();
              final sede = '${e['csNombre'] ?? ''}'.trim();

              final tickets = _ticketsDeEquipo(peId);
              final ticketsTxt = tickets
                  .map((t) => '$prefix - ${t['tiId']}')
                  .join(', ');

              // URLs (mismo patrón de tu servidor)
              const base = 'http://192.168.3.7';
              final marcaEnc = Uri.encodeComponent(marca);
              final modeloEnc = Uri.encodeComponent(modelo);

              final eqImg = '$base/img/Equipos/$marcaEnc/$modeloEnc.png';
              final logoImg = '$base/img/Marcas/$marcaEnc.png';

              return InkWell(
                onTap: peId == 0 ? null : () => onTapEquipo(peId),
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  width: 330,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Imagen equipo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 16 / 6.2,
                          child: Image.network(
                            eqImg,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.dns_rounded,
                                  size: 40,
                                  color: Color(0xFFE0DBF7),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        modelo.isEmpty ? 'Equipo' : modelo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F1B2E),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        [
                          if (fi.isNotEmpty) fi,
                          if (ff.isNotEmpty) ff,
                          if (sede.isNotEmpty) sede,
                        ].join(' - '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF6B667A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 8),

                      _ChipBlue(text: chipPoliza),
                      const SizedBox(height: 6),
                      _ChipGreen(
                        text:
                            venceTxt.isNotEmpty
                                ? 'Póliza vigente (vence $venceTxt)'
                                : 'Póliza vigente',
                      ),

                      const SizedBox(height: 8),

                      if (sn.isNotEmpty)
                        Text(
                          'SN: $sn',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F1B2E),
                          ),
                        ),

                      const SizedBox(height: 4),

                      // Logo marca grande
                      SizedBox(
                        height: 54,
                        child: Image.network(
                          logoImg,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Text(
                              marca.isEmpty ? '' : marca.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1F1B2E),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (tipoPol.isNotEmpty)
                        Text(
                          'Tipo de Póliza: $tipoPol',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1B2E),
                          ),
                        ),

                      if (tickets.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tickets abiertos: $ticketsTxt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF1F1B2E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
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

class _ChipBlue extends StatelessWidget {
  const _ChipBlue({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD8EEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1C7ED6),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChipGreen extends StatelessWidget {
  const _ChipGreen({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF7E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1F8A4C),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
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
