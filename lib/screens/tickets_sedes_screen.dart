import 'package:flutter/material.dart';
import 'package:mrsos/screens/acciones/subir_logs_screen.dart';
import 'package:mrsos/screens/meet_proponer_screen.dart';
import 'package:mrsos/screens/ticket_detail_screen.dart';
import 'package:mrsos/screens/visita_datos_screen.dart';
import '../services/index_service.dart';
import '../services/app_http.dart'; // si tu IndexService usa AppHttp; si no, ajusta el import
import '../widget/mr_skeleton.dart';
import '../widget/colors.dart';
import '../widget/mr_theme.dart';
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
  static const Color chipBg = Color(0xFFEAF0FF);
  // ignore: unused_field
  static const Color chipBorder = Color(0xFFD9D0FF);

  late final IndexService api;
  Map<String, dynamic> indexData = {};
  Map<String, dynamic> stats = {};
  Map<String, dynamic> ticketsSedes = {};
  bool _loading = true;
  Map<String, dynamic> raw = {};
  List<Map<String, dynamic>> sedes = [];

  int? _selectedCsId; // null = ALL
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    api = IndexService(dio: AppHttp.I.dio); // ✅ misma cookie PHPSESSID
    _selectedCsId = widget.initialCsId;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    if (est.isEmpty) {
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
                        color: Color(0xFF3563FF),
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
        bg: Color(0xFFEAF0FF),
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

      if (modo.isEmpty) return 'Proponer un meet';

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
        _MiniChip(text: 'Logs', bg: Color(0xFFEAF0FF), fg: mrPurple),
      ];
    }

    if (proc == 'meet') {
      final modo = (t['tiMeetModo'] ?? '').toString().toLowerCase().trim();
      if (modo.contains('propuesta')) {
        return const [
          _MiniChip(text: 'Asignación', bg: Color(0xFFEAF0FF), fg: mrPurple),
        ];
      }
      return const [
        _MiniChip(text: 'Servicio', bg: Color(0xFFEAF0FF), fg: mrPurple),
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
        final vm = _TicketVM(
          csId: csId,
          csNombre: csNombre,
          clNombre: clNombre,
          prefix: prefix,
          data: t,
        );
        final query = _query.trim().toLowerCase();
        if (query.isNotEmpty) {
          final searchable =
              [
                '$prefix-${t['tiId'] ?? ''}',
                csNombre,
                clNombre,
                t['eqModelo'],
                t['eqVersion'],
                t['maNombre'],
                t['peSN'],
                t['tiProceso'],
              ].join(' ').toLowerCase();
          if (!searchable.contains(query)) continue;
        }
        out.add(vm);
      }
    }
    return out;
  }

  Future<void> _handleTicketAction(_TicketVM vm) async {
    final t = vm.data;
    final proc = _s(t['tiProceso']).toLowerCase().trim();

    if (proc == 'logs') {
      final tiId = int.tryParse(_s(t['tiId'])) ?? 0;
      if (tiId <= 0) return;
      final eqModelo = _s(t['eqModelo']);
      final eqVersion = _s(t['eqVersion']);
      final marca = _s(t['maNombre']);
      final equipoNombre =
          eqVersion.trim().isEmpty ? eqModelo : '$eqModelo $eqVersion';
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (_) => SubirLogsScreen(
                tiId: tiId,
                marca: marca,
                modelo: equipoNombre.isEmpty ? eqModelo : equipoNombre,
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esta acción se habilitará en la siguiente fase.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _ticketsFiltrados();
    final visibleTickets =
        tickets.where((ticket) => !ticket.isSkeleton).toList();
    final actionCount =
        visibleTickets
            .where((ticket) => _accionRequerida(ticket.data) != null)
            .length;

    return Scaffold(
      backgroundColor: MRSColors.bg,
      extendBody: true,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          edgeOffset: 18,
          displacement: 24,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 44),
            children: [
              Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centro de soporte',
                          style: TextStyle(
                            color: MRSColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Todos tus casos en un lugar',
                          style: TextStyle(
                            color: MRSColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundIconButton(icon: Icons.refresh_rounded, onTap: _load),
                ],
              ),
              const SizedBox(height: 22),
              MRPageIntro(
                eyebrow: 'Mesa de ayuda',
                title: 'Tickets de soporte',
                subtitle:
                    actionCount > 0
                        ? 'Tienes $actionCount ${actionCount == 1 ? 'caso que necesita' : 'casos que necesitan'} tu atención.'
                        : 'Todo está en orden. Consulta el avance de cada caso desde aquí.',
              ),
              const SizedBox(height: 20),
              MRSectionCard(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: MRSColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Folio, equipo, serie o sede',
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    else
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: MRSColors.blueSoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: MRSColors.accent,
                          size: 19,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TicketSummaryMetric(
                      icon: Icons.layers_outlined,
                      label: 'Total visibles',
                      value: _loading ? '—' : '${visibleTickets.length}',
                      color: MRSColors.accent,
                      background: MRSColors.blueSoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TicketSummaryMetric(
                      icon: Icons.warning_amber_rounded,
                      label: 'Requieren acción',
                      value: _loading ? '—' : '$actionCount',
                      color: MRSColors.warningText,
                      background: MRSColors.warningBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionLabel(
                title: 'Filtrar por sede',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: MRSkeleton(
                  enabled: _loading,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChipPill(
                        text: 'Todos',
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
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: _SectionLabel(
                      title: 'Casos visibles',
                      icon: Icons.view_agenda_outlined,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MRSColors.blueSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _loading ? '—' : '${visibleTickets.length}',
                      style: const TextStyle(
                        color: MRSColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_loading && visibleTickets.isEmpty)
                const _EmptyTickets()
              else
                ...tickets.map((vm) {
                  if (vm.isSkeleton) return const _TicketCardSkeleton();

                  final t = vm.data;
                  final tiId = (t['tiId'] ?? '').toString();
                  final codigo = '${vm.prefix}-$tiId';
                  final modelo = (t['eqModelo'] ?? '').toString();
                  final version = (t['eqVersion'] ?? '').toString();
                  final marca = (t['maNombre'] ?? '').toString();
                  final sn = (t['peSN'] ?? '').toString();
                  final equipo =
                      version.trim().isEmpty ? modelo : '$modelo $version';
                  final critic = _criticColor(t['tiNivelCriticidad']);
                  final tipo = _tipoStyle(t['tiTipoTicket']?.toString());
                  final accion = _accionRequerida(t);
                  final chips = _chipsEstado(t);
                  final parsedTiId = int.tryParse(tiId) ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _TicketListCard(
                      code: codigo,
                      equipment: equipo.isEmpty ? 'Equipo sin modelo' : equipo,
                      brand: marca,
                      serial: sn,
                      site: vm.csNombre,
                      process:
                          _s(t['tiProceso']).trim().isEmpty
                              ? 'En revisión'
                              : _s(t['tiProceso']),
                      criticColor: critic,
                      type: tipo,
                      chips: chips,
                      action: accion,
                      onAction:
                          accion == null ? null : () => _handleTicketAction(vm),
                      onTap: () {
                        if (parsedTiId <= 0) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => TicketDetailScreen(
                                  tiId: parsedTiId,
                                  folio:
                                      '${t['folio'] ?? 'INE - ${t['tiId']}'}',
                                ),
                          ),
                        );
                      },
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: MRSColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: MRSColors.border),
        ),
        child: Icon(icon, color: MRSColors.primary, size: 21),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MRSColors.accent, size: 19),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: MRSColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets();

  @override
  Widget build(BuildContext context) {
    return MRSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        children: [
          const MRIconBox(
            icon: Icons.check_circle_outline_rounded,
            color: MRSColors.successText,
            background: MRSColors.successBg,
            size: 58,
          ),
          const SizedBox(height: 14),
          const Text(
            'No encontramos tickets',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Prueba otra sede o cambia tu búsqueda.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TicketListCard extends StatelessWidget {
  const _TicketListCard({
    required this.code,
    required this.equipment,
    required this.brand,
    required this.serial,
    required this.site,
    required this.process,
    required this.criticColor,
    required this.type,
    required this.chips,
    required this.action,
    required this.onTap,
    this.onAction,
  });

  final String code;
  final String equipment;
  final String brand;
  final String serial;
  final String site;
  final String process;
  final Color criticColor;
  final _PillStyle type;
  final List<_MiniChip> chips;
  final String? action;
  final VoidCallback onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: MRSColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: MRSColors.border),
            boxShadow: const [
              BoxShadow(
                color: MRSColors.shadow,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 42,
                    decoration: BoxDecoration(
                      color: criticColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            color: MRSColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: MRSColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                site.isEmpty ? 'Sede no indicada' : site,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: MRSColors.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _MiniChipWidget(
                    _MiniChip(text: type.label, bg: type.bg, fg: type.fg),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: MRSColors.muted,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                equipment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MRSColors.text,
                  fontSize: 19,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                [
                  if (brand.trim().isNotEmpty) brand.trim(),
                  if (serial.trim().isNotEmpty) 'SN $serial',
                ].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MRSColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: chips.map(_MiniChipWidget.new).toList(),
              ),
              const SizedBox(height: 16),
              if (action != null)
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MRSColors.warningBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: MRSColors.warningText,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tu siguiente acción',
                                style: TextStyle(
                                  color: MRSColors.warningText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                action!,
                                style: const TextStyle(
                                  color: MRSColors.text,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: MRSColors.warningText,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: MRSColors.border)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        color: MRSColors.teal,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Etapa actual',
                        style: TextStyle(
                          color: MRSColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          process,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MRSColors.text,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

class _TicketSummaryMetric extends StatelessWidget {
  const _TicketSummaryMetric({
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
          const SizedBox(width: 10),
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
