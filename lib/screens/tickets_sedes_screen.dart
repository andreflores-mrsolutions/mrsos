import 'package:flutter/material.dart';
import 'package:mrsos/screens/acciones/subir_logs_screen.dart';
import 'package:mrsos/screens/meet_proponer_screen.dart';
import 'package:mrsos/screens/ticket_detail_screen.dart';
import 'package:mrsos/screens/visita_datos_screen.dart';
import '../services/index_service.dart';
import '../services/app_http.dart'; // si tu IndexService usa AppHttp; si no, ajusta el import
import '../widget/mr_skeleton.dart';
import 'visita_actions_sheet.dart';
import '../services/meet_service.dart';
import 'meet_generar_screen.dart';

import 'meet_cambiar_screen.dart';

class TicketsSedesScreen extends StatefulWidget {
  const TicketsSedesScreen({
    super.key,
    required this.usId,
    required this.userName,
    this.initialCsId,
  });

  final String usId;
  final String userName;
  final int? initialCsId;

  @override
  State<TicketsSedesScreen> createState() => _TicketsSedesScreenState();
}

class _TicketsSedesScreenState extends State<TicketsSedesScreen> {
  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);
  // ignore: unused_field
  static const Color chipBg = Color(0xFFEDE9FF);
  // ignore: unused_field
  static const Color chipBorder = Color(0xFFD9D0FF);
  static const Color textMuted = Color(0xFF6B667A);

  late final IndexService api;
  Map<String, dynamic> indexData = {};
  Map<String, dynamic> stats = {};
  Map<String, dynamic> ticketsSedes = {};
  bool _loading = true;
  Map<String, dynamic> raw = {};
  List<Map<String, dynamic>> sedes = [];

  int? _selectedCsId; // null = ALL

  @override
  void initState() {
    super.initState();
    api = IndexService(dio: AppHttp.I.dio); // ✅ misma cookie PHPSESSID
    _selectedCsId = widget.initialCsId;
    _load();
  }

  String _s(dynamic v) => (v ?? '').toString();

  bool _isMrFromTicket(Map<String, dynamic> t) {
    // Intentamos detectar rol si viene en el listado
    final rol = _s(t['usRol']).toUpperCase().trim();
    if (rol.contains('ADMIN')) return true;
    if (rol.contains('ING')) return true;
    if (rol.contains('MR')) return true;

    // Fallback: si no viene rol, asumimos cliente (false)
    return false;
  }

  Future<void> _openVisitaFlow(Map<String, dynamic> t) async {
    final est = _s(t['tiVisitaEstado']).toLowerCase().trim();

    // 1) Sin visita -> sheet con Asignar / Proponer
    if (est.isEmpty || est == null) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (_) => VisitaAccionesSheet(
              tiId: t['tiId'],
              ticket: t,
              modo: VisitaAccionesModo.crear, // solo Asignar/Proponer
            ),
      );
      return;
    }

    // 2) Pendiente / Confirmar -> sheet con Ver / Modificar / Cancelar
    if (est == 'pendiente' || est == 'confirmar') {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (_) => VisitaAccionesSheet(
              tiId: t['tiId'],
              ticket: t,
              modo: VisitaAccionesModo.gestionar, // Modificar/Cancelar (+ ver)
            ),
      );
      return;
    }
    if (est == 'datos_extra') {
      return;
    }
    // 3) Requiere folio -> directo a Datos
    if (est == 'requiere_folio') {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VisitaDatosScreen(tiId: t['tiId'], ticket: t),
        ),
      );
      if (ok == true) await _load(); // recargar ticket detail
      return;
    }

    // default
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estado de visita no reconocido.')),
    );
  }

  Future<void> _openMeetActions(_TicketVM vm) async {
    final t = vm.data;
    final tiId = int.tryParse(_s(t['tiId'])) ?? 0;
    if (tiId <= 0) return;

    final isMr = _isMrFromTicket(t);

    final estado = _s(t['tiMeetEstado']).toLowerCase().trim();
    final modo = _s(t['tiMeetModo']).toLowerCase().trim();

    final hasMeet = estado.isNotEmpty;
    final pending = estado == 'pendiente';

    final propuestoPorOtro =
        pending &&
        ((isMr && modo == 'propuesta_cliente') ||
            (!isMr && modo == 'propuesta_ingeniero'));

    final apiMeet = MeetService(dio: AppHttp.I.dio);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Acciones de Meet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),

                // ------------- SIN MEET -------------
                if (!hasMeet) ...[
                  ListTile(
                    leading: const Icon(Icons.video_call_rounded),
                    title: const Text(
                      'Generar reunión',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MeetGenerarScreen(tiId: tiId, isMr: isMr),
                        ),
                      );
                      if (ok == true) await _load();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: const Text(
                      'Proponer reunión',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text('3 ventanas sugeridas'),
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MeetProponerScreen(tiId: tiId, isMr: isMr),
                        ),
                      );
                      if (ok == true) await _load();
                    },
                  ),
                ] else ...[
                  // ------------- PROPUESTA DEL OTRO (ACCION REQUERIDA) -------------
                  if (propuestoPorOtro) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF4F46E5),
                      ),
                      title: const Text(
                        'Aceptar meet',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        final r = await apiMeet.aceptarActual(tiId: tiId);
                        if (r['success'] == true) {
                          await _load();
                          return;
                        }
                        final err =
                            (r['error'] ?? 'No se pudo aceptar').toString();
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.swap_horiz_rounded),
                      title: const Text(
                        'Proponer otra fecha',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: const Text('Negar = proponer una nueva'),
                      onTap: () async {
                        Navigator.pop(context);
                        final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) =>
                                    MeetProponerScreen(tiId: tiId, isMr: isMr),
                          ),
                        );
                        if (ok == true) await _load();
                      },
                    ),
                  ],

                  // ------------- YA HAY MEET ACTIVO -------------
                  ListTile(
                    leading: const Icon(Icons.edit_calendar_rounded),
                    title: const Text(
                      'Cambiar reunión',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MeetCambiarScreen(
                                tiId: tiId,
                                isMr: isMr,
                                meetActual:
                                    t, // aquí pasamos el ticket del listado
                              ),
                        ),
                      );
                      if (ok == true) await _load();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Eliminar meet',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final r = await apiMeet.cancelar(
                        tiId: tiId,
                        motivo: 'Cancelado desde quick actions (lista)',
                      );
                      if (r['success'] == true) {
                        await _load();
                        return;
                      }
                      final err =
                          (r['error'] ?? 'No se pudo eliminar').toString();
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await api.obtenerTicketsSedes();
      if (!mounted) return;

      raw = Map<String, dynamic>.from(r);
      final list = (raw['sedes'] is List) ? raw['sedes'] as List : [];

      sedes = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Si el filtro quedó en una sede que ya no existe, lo reseteamos
      if (_selectedCsId != null &&
          !sedes.any((s) => (s['csId'] as int?) == _selectedCsId)) {
        _selectedCsId = null;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async => _load();

  // ---------------- helpers ----------------

  String _prefix3(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return "UNK";
    final cleaned =
        nombre
            .replaceAll(RegExp(r'[^\p{L}]', unicode: true), '') // solo letras
            .toUpperCase();
    return cleaned.length >= 3
        ? cleaned.substring(0, 3)
        : cleaned.padRight(3, 'X');
  }

  Color _criticColor(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s == '1') return const Color(0xFFFF3B30); // rojo grave
    if (s == '2') return const Color(0xFFFF9F0A); // naranja
    return const Color(0xFF34C759); // verde (3 o vacío)
  }

  // Badge tipo ticket: Servicio / Preventivo / Extra
  _PillStyle _tipoStyle(String? tipo) {
    final t = (tipo ?? '').toLowerCase().trim();
    if (t == 'servicio') {
      return const _PillStyle(
        bg: Color(0xFFEAE6FF),
        fg: mrPurple,
        label: 'Servicio',
      );
    }
    if (t == 'preventivo') {
      return const _PillStyle(
        bg: Color(0xFFE6F6FF),
        fg: Color(0xFF0066CC),
        label: 'Preventivo',
      );
    }
    if (t == 'extra') {
      return const _PillStyle(
        bg: Color(0xFFF0F0F5),
        fg: Color(0xFF3A3A45),
        label: 'Extra',
      );
    }
    return const _PillStyle(
      bg: Color(0xFFF0F0F5),
      fg: Color(0xFF3A3A45),
      label: '—',
    );
  }

  // Accion requerida (según tu definición)
  String? _accionRequerida(Map<String, dynamic> t) {
    final proc = (t['tiProceso'] ?? '').toString().toLowerCase().trim();

    // LOGS
    if (proc == 'logs') return 'Se requieren logs';

    // MEET (tiMeetModo)
    if (proc == 'meet') {
      final modo = (t['tiMeetModo'] ?? '').toString().toLowerCase().trim();

      if (modo.isEmpty || modo == null) return 'Proponer un meet';

      if (modo == 'propuesta_ingeniero' || modo == 'asignado_ingeniero') {
        // texto exacto que pediste
        return (modo == 'propuesta_ingeniero')
            ? 'El ingeniero propuso un meet'
            : 'El ingeniero asignó un meet';
      }

      // propuesta_cliente / asignado_cliente => sin acción requerida
      return null;
    }

    // VISITA
    if (proc == 'visita') {
      final est = _s(t['tiVisitaEstado']).toLowerCase().trim();

      // No hay visita
      if (est.isEmpty) return 'Pendiente por asignar visita';

      // Cliente ya la creó / esperando confirmación
      if (est == 'pendiente' || est == 'confirmar') {
        return 'Visita pendiente de confirmación';
      }
      if (est == 'datos_extra') return 'En espera del ingeniero';

      // Ya confirmada -> requiere folio
      if (est == 'requiere_folio') return 'Requiere asignación de folio';

      return null;
    }

    // ENCUESTA
    if (proc == 'encuesta satisfaccion' || proc == 'encuesta de satisfaccion') {
      return 'Encuesta de satisfacción pendiente';
    }

    return null;
  }

  // Chips extra que salen arriba del card (como en tu UI)
  List<_MiniChip> _chipsEstado(Map<String, dynamic> t) {
    final proc = (t['tiProceso'] ?? '').toString().toLowerCase().trim();

    if (proc == 'logs') {
      return const [
        _MiniChip(text: 'Logs', bg: Color(0xFFEAE6FF), fg: mrPurple),
      ];
    }

    if (proc == 'meet') {
      final modo = (t['tiMeetModo'] ?? '').toString().toLowerCase().trim();
      if (modo.contains('propuesta')) {
        return const [
          _MiniChip(text: 'Asignación', bg: Color(0xFFEAE6FF), fg: mrPurple),
        ];
      }
      return const [
        _MiniChip(text: 'Servicio', bg: Color(0xFFEAE6FF), fg: mrPurple),
      ];
    }

    if (proc == 'visita') {
      return const [
        _MiniChip(text: 'visita', bg: Color(0xFFF0F0F5), fg: Color(0xFF3A3A45)),
      ];
    }

    if (proc == 'encuesta satisfaccion' || proc == 'encuesta de satisfaccion') {
      return const [
        _MiniChip(
          text: 'encuesta satis..',
          bg: Color(0xFFFFF3D6),
          fg: Color(0xFF8A5A00),
        ),
      ];
    }

    // fallback
    final tipo = _tipoStyle(t['tiTipoTicket']?.toString());
    return [_MiniChip(text: proc, bg: tipo.bg, fg: tipo.fg)];
  }

  // Flatten tickets según filtro
  List<_TicketVM> _ticketsFiltrados() {
    if (_loading) return List.generate(3, (_) => _TicketVM.skeleton());

    final out = <_TicketVM>[];
    for (final s in sedes) {
      final csId = (s['csId'] as int?) ?? 0;
      if (_selectedCsId != null && csId != _selectedCsId) continue;

      final clNombre = (s['clNombre'] ?? '').toString();
      final csNombre = (s['csNombre'] ?? '').toString();
      final prefix = _prefix3(clNombre);

      final tickets = (s['tickets'] is List) ? s['tickets'] as List : const [];
      for (final tt in tickets) {
        final t = Map<String, dynamic>.from(tt as Map);
        out.add(
          _TicketVM(
            csId: csId,
            csNombre: csNombre,
            clNombre: clNombre,
            prefix: prefix,
            data: t,
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _ticketsFiltrados();

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          edgeOffset: 12,
          displacement: 18,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              // AppBar “manual” (como tu screenshot)
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Grupos/Sedes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance
                ],
              ),
              const SizedBox(height: 6),

              // Chips filtro sedes
              SizedBox(
                height: 44,
                child: MRSkeleton(
                  enabled: _loading,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChipPill(
                        text: 'All',
                        selected: _selectedCsId == null,
                        onTap: () => setState(() => _selectedCsId = null),
                      ),
                      const SizedBox(width: 10),
                      ...sedes.map((s) {
                        final csId = (s['csId'] as int?) ?? 0;
                        final name = (s['csNombre'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _FilterChipPill(
                            text: name,
                            selected: _selectedCsId == csId,
                            onTap: () => setState(() => _selectedCsId = csId),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Lista de tickets (cards)
              ...tickets.map((vm) {
                if (vm.isSkeleton) return const _TicketCardSkeleton();

                final t = vm.data;
                final tiId = (t['tiId'] ?? '').toString();
                final codigo = '${vm.prefix}-$tiId';

                final modelo = (t['eqModelo'] ?? '').toString();
                final version = (t['eqVersion'] ?? '').toString();
                final marca = (t['maNombre'] ?? '').toString();
                final sn = (t['peSN'] ?? '').toString();

                final equipo = (version.trim().isEmpty) ? modelo : modelo;
                final critic = _criticColor(t['tiNivelCriticidad']);
                final tipo = _tipoStyle(t['tiTipoTicket']?.toString());
                final accion = _accionRequerida(t);

                final chips = _chipsEstado(t);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => TicketDetailScreen(
                                tiId: int.parse(tiId),
                                folio: '${t['folio'] ?? 'INE - ${t['tiId']}'}',
                              ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: critic, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top line: SN + Marca + badge ENE-xx
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'SN: $sn · $marca',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE7EC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  codigo,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: mrPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Equipo
                          Text(
                            equipo.isEmpty ? 'Equipo sin modelo' : equipo,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Badges row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...chips.map((c) => _MiniChipWidget(c)),
                              _MiniChipWidget(
                                _MiniChip(
                                  text: tipo.label,
                                  bg: tipo.bg,
                                  fg: tipo.fg,
                                ),
                              ),
                            ],
                          ),

                          // Acción requerida
                          if (accion != null) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Acción Requerida:',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: InkWell(
                                onTap: () async {
                                  final proc =
                                      _s(t['tiProceso']).toLowerCase().trim();

                                  if (proc == 'logs') {
                                    final tiId = t['tiId'];
                                    if (tiId <= 0) return;

                                    final eqModelo = _s(t['eqModelo']);
                                    final eqVersion = _s(t['eqVersion']);
                                    final marca = _s(t['maNombre']);
                                    final equipoNombre =
                                        (eqVersion.trim().isEmpty)
                                            ? eqModelo
                                            : '$eqModelo $eqVersion';

                                    final ok = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => SubirLogsScreen(
                                              tiId: tiId,
                                              marca: marca,
                                              modelo:
                                                  equipoNombre.isEmpty
                                                      ? eqModelo
                                                      : equipoNombre,
                                            ),
                                      ),
                                    );

                                    if (ok == true) await _load();
                                    return;
                                  }

                                  if (proc == 'meet') {
                                    await _openMeetActions(vm);
                                    return;
                                  }
                                  if (proc == 'visita') {
                                    await _openVisitaFlow(t);
                                    return;
                                  }

                                  // VISITA / ENCUESTA (si luego quieres abrir quick screens)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Esta acción se habilitará en la siguiente fase.',
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3D6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    accion,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      color: Color(0xFF8A5A00),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- UI components --------------------

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? mrPurple : const Color.fromARGB(255, 233, 238, 255),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD9D0FF), width: 1.3),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : mrPurple,
          ),
        ),
      ),
    );
  }
}

class _TicketCardSkeleton extends StatelessWidget {
  const _TicketCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8F2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 12, width: 220)),
              SizedBox(width: 10),
              SkeletonBox(height: 24, width: 64, radius: 10),
            ],
          ),
          SizedBox(height: 10),
          SkeletonBox(height: 16, width: 200),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonBox(height: 22, width: 80, radius: 99),
              SizedBox(width: 8),
              SkeletonBox(height: 22, width: 90, radius: 99),
              SizedBox(width: 8),
              SkeletonBox(height: 22, width: 70, radius: 99),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChipWidget extends StatelessWidget {
  const _MiniChipWidget(this.c);
  final _MiniChip c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        c.text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: c.fg,
        ),
      ),
    );
  }
}

// -------------------- View models --------------------

class _TicketVM {
  final int csId;
  final String csNombre;
  final String clNombre;
  final String prefix;
  final Map<String, dynamic> data;
  final bool isSkeleton;

  _TicketVM({
    required this.csId,
    required this.csNombre,
    required this.clNombre,
    required this.prefix,
    required this.data,
  }) : isSkeleton = false;

  _TicketVM.skeleton()
    : csId = 0,
      csNombre = '',
      clNombre = '',
      prefix = '',
      data = const {},
      isSkeleton = true;
}

class _MiniChip {
  final String text;
  final Color bg;
  final Color fg;
  const _MiniChip({required this.text, required this.bg, required this.fg});
}

class _PillStyle {
  final Color bg;
  final Color fg;
  final String label;
  const _PillStyle({required this.bg, required this.fg, required this.label});
}

// -------------------- QuickAction placeholders --------------------

class QuickLogsScreen extends StatelessWidget {
  const QuickLogsScreen({super.key, required this.vm});
  final _TicketVM vm;

  @override
  Widget build(BuildContext context) {
    final tiId = vm.data['tiId'];
    return Scaffold(
      appBar: AppBar(title: Text('Logs · ${vm.prefix}-$tiId')),
      body: const Center(
        child: Text('Pantalla completa de Logs (pendiente de implementar)'),
      ),
    );
  }
}

class QuickMeetScreen extends StatelessWidget {
  const QuickMeetScreen({super.key, required this.vm});
  final _TicketVM vm;

  @override
  Widget build(BuildContext context) {
    final tiId = vm.data['tiId'];
    return Scaffold(
      appBar: AppBar(title: Text('Meet · ${vm.prefix}-$tiId')),
      body: const Center(
        child: Text('Pantalla completa de Meet (pendiente de implementar)'),
      ),
    );
  }
}

class QuickVisitaScreen extends StatelessWidget {
  const QuickVisitaScreen({super.key, required this.vm});
  final _TicketVM vm;

  @override
  Widget build(BuildContext context) {
    final tiId = vm.data['tiId'];
    return Scaffold(
      appBar: AppBar(title: Text('Visita · ${vm.prefix}-$tiId')),
      body: const Center(
        child: Text('Pantalla completa de Visita (pendiente de implementar)'),
      ),
    );
  }
}

class QuickEncuestaScreen extends StatelessWidget {
  const QuickEncuestaScreen({super.key, required this.vm});
  final _TicketVM vm;

  @override
  Widget build(BuildContext context) {
    final tiId = vm.data['tiId'];
    return Scaffold(
      appBar: AppBar(title: Text('Encuesta · ${vm.prefix}-$tiId')),
      body: const Center(
        child: Text('Pantalla completa de Encuesta (pendiente de implementar)'),
      ),
    );
  }
}
