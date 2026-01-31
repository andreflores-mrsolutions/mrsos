import 'package:flutter/material.dart';
import 'package:mrsos/screens/ticket_detail_screen.dart';
import 'package:mrsos/services/app_http.dart';
import '../../services/equipos_service.dart';
import '../../widget/mr_skeleton.dart';

class MisEquiposDetalleScreen extends StatefulWidget {
  const MisEquiposDetalleScreen({super.key, required this.peId});
  final int peId;

  @override
  State<MisEquiposDetalleScreen> createState() =>
      _MisEquiposDetalleScreenState();
}

class _MisEquiposDetalleScreenState extends State<MisEquiposDetalleScreen> {
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  late final EquiposService _api;
  bool _loading = true;

  Map<String, dynamic> _d = {};
  List<dynamic> _e = [];

  // extras del JSON
  String _prefix = '';
  String _polizaDesc = '';
  String _disclaimer = '';

  @override
  void initState() {
    super.initState();
    _api = EquiposService(dio: AppHttp.I.dio);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.detalleEquipo(peId: widget.peId);
      if (!mounted) return;

      if (r['success'] == true) {
        setState(() {
          _d = Map<String, dynamic>.from(r['equipo'] ?? {});
          _e = List<dynamic>.from(r['ticketsAbiertos'] ?? []);
          _prefix = (r['prefix'] ?? '').toString();
          _polizaDesc = (r['polizaDescripcion'] ?? '').toString();
          _disclaimer = (r['disclaimer'] ?? '').toString();
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

  String _imgEquipo(String marca, String modelo) {
    final m = Uri.encodeComponent(marca);
    final mo = Uri.encodeComponent(modelo);
    return 'https://yellow-chicken-910471.hostingersite.com/img/Equipos/$m/$mo.png';
  }

  String _imgMarca(String marca) {
    final m = Uri.encodeComponent(marca);
    return 'https://yellow-chicken-910471.hostingersite.com/img/Marcas/$m.png';
  }

  Color _critColor(dynamic c) {
    final v = int.tryParse('$c') ?? 3;
    if (v == 1) return const Color(0xFFE53935); // rojo
    if (v == 2) return const Color(0xFFFFA000); // ámbar
    return const Color(0xFF2E7D32); // verde
  }

  ({Color bg, Color fg}) _tipoBadge(String tipo) {
    final t = tipo.toLowerCase().trim();
    if (t == 'preventivo') {
      return (bg: const Color(0xFFE8F1FF), fg: const Color(0xFF1C7ED6));
    }
    if (t == 'extra') {
      return (bg: const Color(0xFFFFEEF1), fg: const Color(0xFFD81B60));
    }
    // Servicio default
    return (bg: const Color.fromARGB(255, 230, 232, 255), fg: mrPurple);
  }

  String _folio(dynamic tiId) {
    final id = int.tryParse('$tiId') ?? 0;
    final p = _prefix.isEmpty ? 'TKT' : _prefix;
    return '$p - $id';
  }

  Widget _kLine(String k, String v) {
    if (v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1F1B2E),
          ),
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(
              text: v,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B667A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelo = '${_d['eqModelo'] ?? 'Equipo'}'.trim();
    final version = '${_d['eqVersion'] ?? ''}'.trim();
    final marca = '${_d['maNombre'] ?? ''}'.trim();
    final sn = '${_d['peSN'] ?? ''}'.trim();

    final sede = '${_d['csNombre'] ?? ''}'.trim();
    final cliente = '${_d['clNombre'] ?? ''}'.trim();

    final tipoEquipo = '${_d['eqTipoEquipo'] ?? ''}'.trim();
    final peDesc = '${_d['peDescripcion'] ?? ''}'.trim();
    final so = '${_d['peSO'] ?? ''}'.trim();

    final cpu = '${_d['eqCPU'] ?? ''}'.trim();
    final ram = '${_d['eqMaxRAM'] ?? ''}'.trim();
    final nic = '${_d['eqNIC'] ?? ''}'.trim();
    final eqDesc = '${_d['eqDescripcion'] ?? ''}'.trim();

    final pcTipo = '${_d['pcTipoPoliza'] ?? ''}'.trim();
    final pcIdent = '${_d['pcIdentificador'] ?? _d['pcNombre'] ?? ''}'.trim();
    final vence = '${_d['pcFechaFin'] ?? ''}'.trim();

    final hasTickets = _e.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          modelo,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              // Imagen equipo
              MRSkeleton(
                enabled: _loading,
                child: SizedBox(
                  height: 170,
                  child: Image.network(
                    _imgEquipo(marca, modelo),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Card equipo (nombre + sn + logo)
              MRSkeleton(
                enabled: _loading,
                child: Container(
                  height: 130,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$modelo${version.isEmpty ? '' : ' $version'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              sn.isEmpty ? '' : 'SN: $sn',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B667A),
                              ),
                            ),
                            const Spacer(),
                            if (sede.isNotEmpty || cliente.isNotEmpty)
                              Text(
                                [
                                  cliente,
                                  sede,
                                ].where((x) => x.trim().isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B667A),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 84,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Image.network(
                            _imgMarca(marca),
                            height: 26,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) => Text(
                                  marca.isEmpty ? '' : marca.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // póliza + descargar (UI)
              MRSkeleton(
                enabled: _loading,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Pill(
                            text:
                                pcIdent.isEmpty ? 'Póliza' : 'Póliza $pcIdent',
                          ),
                          const SizedBox(width: 10),
                          _Pill(
                            text: 'Descargar',
                            bg: const Color(0xFFD9F0FF),
                            fg: mrPurple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _Pill(
                        text:
                            vence.isEmpty
                                ? 'Póliza vigente'
                                : 'Póliza vigente (vence $vence)',
                        bg: const Color(0xFFE8FFE8),
                        fg: const Color(0xFF1B7A32),
                      ),
                      const SizedBox(height: 10),
                      if (pcTipo.isNotEmpty)
                        Text(
                          'Tipo de Póliza: $pcTipo',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F1B2E),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Tickets abiertos (AQUÍ estaba el faltante)
              if (_loading)
                MRSkeleton(
                  enabled: true,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                )
              else if (hasTickets) ...[
                const Text(
                  'Tickets abiertos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1B2E),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 138,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _e.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final t = Map<String, dynamic>.from(_e[i] as Map);
                      final folio = _folio(t['tiId']);
                      final proc = '${t['tiProceso'] ?? ''}'.trim();
                      final tipo = '${t['tiTipoTicket'] ?? ''}'.trim();
                      final crit = '${t['tiNivelCriticidad'] ?? ''}'.trim();
                      final est = '${t['tiEstatus'] ?? ''}'.trim();

                      final cc = _critColor(crit);
                      final badge = _tipoBadge(tipo);

                      return GestureDetector(
                        onTap: () {
                          // abrir detalle ticket
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => TicketDetailScreen(
                                    tiId: int.tryParse('${t['tiId']}') ?? 0,
                                    folio: _folio(t['tiId']),
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          width: 210,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cc, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folio,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F1B2E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _MiniBadge(
                                    text: tipo.isEmpty ? 'Servicio' : tipo,
                                    bg: badge.bg,
                                    fg: badge.fg,
                                  ),
                                  const SizedBox(width: 8),
                                  _MiniBadge(
                                    text: 'C$crit',
                                    bg: cc.withOpacity(0.14),
                                    fg: cc,
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (proc.isNotEmpty)
                                Text(
                                  proc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B667A),
                                  ),
                                ),
                              if (est.isNotEmpty)
                                Text(
                                  est,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F1B2E),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Características (YA con datos reales)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Características',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (tipoEquipo.isNotEmpty)
                            _Pill(
                              text: tipoEquipo,
                              bg: const Color(0xFFD9F0FF),
                              fg: mrPurple,
                            ),
                          const SizedBox(height: 12),

                          if (peDesc.isNotEmpty) ...[
                            const Text(
                              'Uso / Nota',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              peDesc,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B667A),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          const Text(
                            'General',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          _kLine('SO', so),
                          _kLine('CPU', cpu),
                          _kLine('RAM Máx.', ram),
                          _kLine('NIC', nic),
                          _kLine('Sede', sede),
                          if (eqDesc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              eqDesc,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B667A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tooltip(
                      padding: const EdgeInsets.all(0),
                      decoration: const BoxDecoration(color: Color(0xffE7E5FB)),
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 5),
                      richMessage: WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Row(
                            children: [
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 200,
                                child: Text(
                                  _disclaimer.isNotEmpty
                                      ? _disclaimer
                                      : 'Info referencial. Si necesitas detalle, contacta a tu BDM.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: Icon(Icons.info, size: 24),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ¿Qué incluye mi póliza? (usa lo que ya viene en JSON)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Pill(
                            text:
                                'Póliza ${pcTipo.isEmpty ? 'Platinum' : pcTipo}',
                            bg: const Color(0xFFD9F0FF),
                            fg: mrPurple,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '¿Qué incluye mi póliza?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _polizaDesc.isNotEmpty
                                ? _polizaDesc
                                : 'Información no disponible.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          if (_disclaimer.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _disclaimer,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8F8AA3),
                                height: 1.35,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tooltip(
                      padding: const EdgeInsets.all(0),
                      decoration: const BoxDecoration(color: Color(0xffE7E5FB)),
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 5),
                      richMessage: WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Row(
                            children: [
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 200,
                                child: Text(
                                  _disclaimer.isNotEmpty
                                      ? _disclaimer
                                      : 'Info referencial. Si necesitas detalle, contacta a tu BDM.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: Icon(Icons.info, size: 24),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    this.bg = const Color.fromARGB(255, 230, 232, 255),
    this.fg = const Color(0xFF200F4C),
  });
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
