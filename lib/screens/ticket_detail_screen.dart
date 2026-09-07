import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mrsos/screens/acciones/subir_logs_screen.dart';
import 'package:mrsos/screens/meet_cambiar_screen.dart';
import 'package:mrsos/screens/meet_generar_screen.dart';
import 'package:mrsos/screens/meet_proponer_screen.dart';
import 'package:mrsos/screens/visita_actions_sheet.dart';
import 'package:mrsos/screens/visita_datos_screen.dart';
import 'package:mrsos/services/meet_service.dart';
import '../services/index_service.dart';
import '../services/app_http.dart'; // o tu cliente Dio actual
import '../widget/colors.dart';
import '../widget/mr_skeleton.dart';
import '../widget/mr_theme.dart';

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.tiId,
    required this.folio, // "INE - 12" o "ENE-12" como quieras mostrar en header
  });

  final int tiId;
  final String folio;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);
  static const Color textMuted = Color(0xFF71809D);

  late final IndexService api;

  bool _loading = true;
  Map<String, dynamic> d = {};

  // Orden de procesos (para %)
  static const List<String> procesos = [
    'asignacion',
    'revision inicial',
    'logs',
    'meet',
    'revision especial',
    'espera refaccion',
    'visita',
    'fecha asignada',
    'espera ventana',
    'espera visita',
    'en camino',
    'espera documentacion',
    'encuesta satisfaccion',
    'finalizado',
    'cancelado',
    'fuera de alcance',
    'servicio por evento',
  ];

  @override
  void initState() {
    super.initState();
    api = IndexService(dio: AppHttp.I.dio); // ✅ misma cookie PHPSESSID
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await api.detalleTicket(tiId: widget.tiId);
      final ticket =
          (r['ticket'] is Map)
              ? Map<String, dynamic>.from(r['ticket'])
              : <String, dynamic>{};

      setState(() => d = ticket);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  bool _isMrFromTicket(Map<String, dynamic> t) {
    final rol = _s(t['usRol']).toUpperCase();
    if (rol.contains('MR')) return true;
    if (rol.contains('ADMIN')) return true;
    return false; // default cliente
  }

  Future<void> _openMeetActions() async {
    final isMr = _isMrFromTicket(d);

    final estado = _s(d['tiMeetEstado']).toLowerCase().trim();
    final modo = _s(d['tiMeetModo']).toLowerCase().trim();

    final hasMeet = estado.isNotEmpty;
    final pending = estado == 'pendiente';

    final propuestoPorOtro =
        pending &&
        ((isMr && modo == 'propuesta_cliente') ||
            (!isMr && modo == 'propuesta_ingeniero'));

    final api = MeetService(dio: AppHttp.I.dio);

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

                if (!hasMeet) ...[
                  ListTile(
                    leading: const Icon(Icons.video_call_rounded),
                    title: const Text(
                      'Generar reunión',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MeetGenerarScreen(
                                tiId: widget.tiId,
                                isMr: isMr,
                              ),
                        ),
                      );
                      if (ok == true) await _load();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: const Text(
                      'Proponer reunión',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('3 ventanas sugeridas'),
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MeetProponerScreen(
                                tiId: widget.tiId,
                                isMr: isMr,
                              ),
                        ),
                      );
                      if (ok == true) await _load();
                    },
                  ),
                ] else ...[
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
                        final r = await api.aceptarActual(tiId: widget.tiId);
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
                                (_) => MeetProponerScreen(
                                  tiId: widget.tiId,
                                  isMr: isMr,
                                ),
                          ),
                        );
                        if (ok == true) await _load();
                      },
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.edit_calendar_rounded),
                    title: const Text(
                      'Cambiar reunión',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MeetCambiarScreen(
                                tiId: widget.tiId,
                                isMr: isMr,
                                meetActual: d,
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
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final r = await api.cancelar(
                        tiId: widget.tiId,
                        motivo: 'Cancelado desde acciones',
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

  // ---------------- helpers ----------------

  String _s(dynamic v, [String fb = '']) => (v ?? fb).toString();

  double _progressFromProceso(String p) {
    final pNorm = p.toLowerCase().trim();
    final idx = procesos.indexWhere((x) => x.toLowerCase() == pNorm);
    if (idx < 0) return 0.0;
    final denom = math.max(1, procesos.length - 1);
    return (idx / denom).clamp(0.0, 1.0);
    // Si prefieres que "finalizado" sea 100% siempre: puedes forzar:
    // if (pNorm == 'finalizado') return 1.0;
  }

  // Acción requerida (igual que ya venimos manejando)
  String? _accionRequerida(Map<String, dynamic> t) {
    final proc = _s(t['tiProceso']).toLowerCase().trim();

    if (proc == 'logs') return 'Se requieren logs';

    if (proc == 'meet') {
      final modo = _s(t['tiMeetModo']).toLowerCase().trim();
      if (modo.isEmpty) return 'Proponer un meet';

      if (modo == 'propuesta_ingeniero' || modo == 'asignado_ingeniero') {
        return (modo == 'propuesta_ingeniero')
            ? 'El ingeniero propuso un meet'
            : 'El ingeniero asignó un meet';
      }

      // propuesta_cliente / asignado_cliente => sin acción requerida
      return null;
    }

    if (proc == 'visita') {
      final est = _s(t['tiVisitaEstado']).toLowerCase().trim();
      if (est == 'pendiente') return 'Pendiente por asignar visita';
      if (est == 'requiere_folio') return 'Requiere asignación de folio';
      return null;
    }

    if (proc == 'encuesta satisfaccion' || proc == 'encuesta de satisfaccion') {
      return 'Encuesta de satisfacción pendiente';
    }

    return null;
  }

  Future<void> _handlePrimaryAction() async {
    final proc = _s(d['tiProceso']).toLowerCase().trim();

    if (proc == 'logs') {
      final tiId = widget.tiId;
      if (tiId <= 0) return;
      final eqModelo = _s(d['eqModelo']);
      final eqVersion = _s(d['eqVersion']);
      final marca = _s(d['maNombre']);
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
      await _openMeetActions();
      return;
    }
    if (proc == 'visita') {
      await _openVisitaFlow(d);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esta acción se habilitará en la siguiente fase.'),
      ),
    );
  }

  // URLs imagenes (escapando espacios)
  String _equipImgUrl({
    required String marca,
    required String modeloSinVersion,
  }) {
    final m = Uri.encodeComponent(marca.trim());
    final mod = Uri.encodeComponent(modeloSinVersion.trim());
    return 'https://mrsos.com.mx/img/Equipos/$m/$mod.png';
  }

  String _brandUrl(String marca) {
    final m = Uri.encodeComponent(marca.trim());
    return 'https://mrsos.com.mx/img/Marcas/$m.png';
  }

  @override
  Widget build(BuildContext context) {
    final eqModelo = _s(d['eqModelo']);
    final eqVersion = _s(d['eqVersion']);
    final marca = _s(d['maNombre']);
    final sn = _s(d['peSN']);
    final desc = _s(d['tiDescripcion']);
    final diag = _s(d['tiDiagnostico']);
    final proc = _s(d['tiProceso']);
    final critic = _s(d['tiNivelCriticidad'], '3');
    final ticketType = _s(d['tiTipoTicket'], 'Servicio');
    final site = _s(d['csNombre']);
    final creation = _s(d['tiFechaCreacion'], 'Fecha no disponible');
    final assignment = _s(d['tiFechaAsignacion'], 'Aún sin asignar');
    final equipmentName =
        eqVersion.trim().isEmpty ? eqModelo : '$eqModelo $eqVersion';
    final imageUrl = _equipImgUrl(marca: marca, modeloSinVersion: eqModelo);
    final brandUrl = _brandUrl(marca);
    final progress = _progressFromProceso(proc);
    final action = _accionRequerida(d);
    final criticColor =
        critic == '1'
            ? MRSColors.dangerText
            : critic == '2'
            ? MRSColors.warningText
            : MRSColors.successText;

    return Scaffold(
      backgroundColor: MRSColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 48),
            children: [
              Row(
                children: [
                  _DetailIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalle del caso',
                          style: TextStyle(
                            color: MRSColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.folio,
                          style: const TextStyle(
                            color: MRSColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DetailIconButton(icon: Icons.refresh_rounded, onTap: _load),
                ],
              ),
              const SizedBox(height: 22),
              MRSkeleton(
                enabled: _loading,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF091638), Color(0xFF23448E)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2911245C),
                        blurRadius: 30,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -45,
                        top: -70,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .05),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .08),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  widget.folio,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: criticColor.withValues(alpha: .20),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: criticColor.withValues(alpha: .45),
                                  ),
                                ),
                                child: Text(
                                  'Criticidad $critic',
                                  style: TextStyle(
                                    color:
                                        criticColor == MRSColors.warningText
                                            ? const Color(0xFFFFD071)
                                            : criticColor ==
                                                MRSColors.dangerText
                                            ? const Color(0xFFFFA5AD)
                                            : const Color(0xFF77E0B2),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          Text(
                            equipmentName.isEmpty
                                ? 'Equipo relacionado'
                                : equipmentName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1.08,
                              letterSpacing: -1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [
                              if (marca.isNotEmpty) marca,
                              if (site.isNotEmpty) site,
                              if (sn.isNotEmpty) 'SN $sn',
                            ].join('  ·  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .66),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  proc.trim().isEmpty ? 'En revisión' : proc,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              backgroundColor: Colors.white.withValues(
                                alpha: .12,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                MRSColors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!_loading && action != null) ...[
                const SizedBox(height: 18),
                _Card(
                  color: MRSColors.warningBg,
                  borderColor: const Color(0xFFFFE1A6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MRIconBox(
                            icon: Icons.bolt_rounded,
                            color: MRSColors.warningText,
                            background: Color(0xFFFFE9BC),
                            size: 46,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Necesitamos algo de ti',
                                  style: TextStyle(
                                    color: MRSColors.warningText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  action,
                                  style: const TextStyle(
                                    color: MRSColors.text,
                                    fontSize: 16,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _handlePrimaryAction,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Resolver acción'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              MRSkeleton(
                enabled: _loading,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DetailSectionTitle(
                        icon: Icons.inventory_2_outlined,
                        title: 'Equipo relacionado',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 104,
                            height: 92,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MRSColors.blueSoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                    Icons.dns_rounded,
                                    color: MRSColors.accent,
                                    size: 36,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  equipmentName.isEmpty
                                      ? 'Equipo'
                                      : equipmentName,
                                  style: const TextStyle(
                                    color: MRSColors.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  sn.isEmpty ? 'Sin número de serie' : 'SN $sn',
                                  style: const TextStyle(
                                    color: MRSColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 24,
                                  child: Image.network(
                                    brandUrl,
                                    alignment: Alignment.centerLeft,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (_, __, ___) => Text(
                                          marca,
                                          style: const TextStyle(
                                            color: MRSColors.text,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              MRSkeleton(
                enabled: _loading,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DetailSectionTitle(
                        icon: Icons.notes_rounded,
                        title: 'Resumen del caso',
                      ),
                      const SizedBox(height: 18),
                      _NarrativeBlock(
                        label: 'Descripción reportada',
                        value:
                            desc.isEmpty ? 'Descripción no disponible.' : desc,
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                      const SizedBox(height: 14),
                      _NarrativeBlock(
                        label: 'Diagnóstico del especialista',
                        value:
                            diag.isEmpty
                                ? 'El diagnóstico está en proceso.'
                                : diag,
                        icon: Icons.medical_information_outlined,
                        accent: MRSColors.teal,
                        background: MRSColors.tealSoft,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              MRSkeleton(
                enabled: _loading,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DetailSectionTitle(
                        icon: Icons.fact_check_outlined,
                        title: 'Datos del ticket',
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.category_outlined,
                        label: 'Tipo',
                        value: ticketType,
                      ),
                      const SizedBox(height: 13),
                      _InfoRow(
                        icon: Icons.flag_outlined,
                        label: 'Proceso',
                        value: proc.isEmpty ? 'En revisión' : proc,
                      ),
                      const SizedBox(height: 13),
                      _InfoRow(
                        icon: Icons.schedule_rounded,
                        label: 'Creado',
                        value: creation,
                      ),
                      const SizedBox(height: 13),
                      _InfoRow(
                        icon: Icons.engineering_outlined,
                        label: 'Asignado',
                        value: assignment,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    // Mapeo esperado del PHP (ajusta nombres si tu JSON usa otros)
    final eqModelo = _s(d['eqModelo']);
    final eqVersion = _s(d['eqVersion']);
    final marca = _s(d['maNombre']);
    final sn = _s(d['peSN']);
    final desc = _s(d['tiDescripcion']);
    final diag = _s(d['tiDiagnostico']);
    final proc = _s(d['tiProceso']);
    final critic = _s(d['tiNivelCriticidad'], '3');
    _s(d['tiTipoTicket']);

    final equipoNombre =
        (eqVersion.trim().isEmpty) ? eqModelo : '$eqModelo $eqVersion';

    // imagen del equipo SIN version
    final modeloSinVersion =
        eqModelo; // (como dijiste: modelo aquí sin version.png)
    final imgEquipo = _equipImgUrl(
      marca: marca,
      modeloSinVersion: modeloSinVersion,
    );
    final imgMarca = _brandUrl(marca);

    final progress = _progressFromProceso(proc);
    final accion = _accionRequerida(d);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.folio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 10),

              // Card equipo + imagen
              MRSkeleton(
                enabled: _loading,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 7,
                        child: Container(
                          color: const Color(0xFFF7F9FC),

                          child: Image.network(
                            imgEquipo,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 34,
                                    color: Color(0xFFB8B6C6),
                                  ),
                                ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              equipoNombre.isEmpty ? 'Equipo' : equipoNombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SN: $sn',
                              style: const TextStyle(
                                color: textMuted,
                                fontWeight: FontWeight.w500,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 30,
                              child: Image.network(
                                imgMarca,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Descripción + progreso
              MRSkeleton(
                enabled: _loading,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Descripción:',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9FFF0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Color(0xFF18A957),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        desc.isEmpty ? 'Descripción no disponible' : desc,
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Diagnostico:',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9FFF0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.healing_rounded,
                              size: 16,
                              color: Color.fromARGB(255, 51, 24, 169),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        diag.isEmpty
                            ? 'Por el momento estamos diagnosticando el ticket c:'
                            : diag,
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Badge de proceso (como "Encuesta de Satisfacción")
                      if (!_loading && proc.trim().isNotEmpty)
                        _Badge(
                          text: proc,
                          bg: const Color(0xFFFFE7EC),
                          fg: mrPurple,
                        ),

                      const SizedBox(height: 28),

                      // Barra progreso
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFEAF0FF),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            mrPurple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          '${(progress * 100).round()}% Completado',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Info: criticidad + fechas
              MRSkeleton(
                enabled: _loading,
                child: _Card(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Nivel de criticidad:',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _Badge(
                            text: 'Nivel$critic',
                            bg: const Color.fromARGB(255, 233, 238, 255),
                            fg: mrPurple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _InfoRow(
                        icon: Icons.access_time_rounded,
                        label: 'Creación del ticket:',
                        value: _s(
                          d['tiFechaCreacion'],
                          '00:00 - 00-00-00:00:00 PM',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.access_time_rounded,
                        label: 'Creación del ticket:',
                        value: _s(
                          d['tiFechaAsignacion'],
                          '00:00 - 00-00-00:00:00 PM',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Acción requerida
              MRSkeleton(
                enabled: _loading,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Acción requerida:',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        accion ?? '—',
                        style: const TextStyle(
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (accion != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            onTap: () async {
                              final proc =
                                  _s(d['tiProceso']).toLowerCase().trim();

                              if (proc == 'logs') {
                                final tiId = widget.tiId;
                                if (tiId <= 0) return;

                                final eqModelo = _s(d['eqModelo']);
                                final eqVersion = _s(d['eqVersion']);
                                final marca = _s(d['maNombre']);
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
                                await _openMeetActions();
                                return;
                              }

                              if (proc == 'visita') {
                                await _openVisitaFlow(d);
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
            ],
          ),
        ),
      ),
    );
  }
}

// ----------- UI small widgets -----------

class _DetailIconButton extends StatelessWidget {
  const _DetailIconButton({required this.icon, required this.onTap});

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

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MRIconBox(
          icon: icon,
          color: MRSColors.accent,
          background: MRSColors.blueSoft,
          size: 40,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: MRSColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _NarrativeBlock extends StatelessWidget {
  const _NarrativeBlock({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = MRSColors.accent,
    this.background = MRSColors.blueSoft,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: MRSColors.text,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
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

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.color = MRSColors.surface,
    this.borderColor = MRSColors.border,
  });
  final Widget child;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: MRSColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MRSColors.blueSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: MRSColors.accent),
        ),
        const SizedBox(width: 11),
        Text(
          label,
          style: const TextStyle(
            color: MRSColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: MRSColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
