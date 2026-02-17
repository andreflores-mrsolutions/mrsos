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
import '../widget/mr_skeleton.dart';

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
  static const Color textMuted = Color(0xFF6B667A);

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
                        color: Color(0xFF4F46E5),
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

  // URLs imagenes (escapando espacios)
  String _equipImgUrl({
    required String marca,
    required String modeloSinVersion,
  }) {
    final m = Uri.encodeComponent(marca.trim());
    final mod = Uri.encodeComponent(modeloSinVersion.trim());
    return 'http://192.168.3.7/img/Equipos/$m/$mod.png';
  }

  String _brandUrl(String marca) {
    final m = Uri.encodeComponent(marca.trim());
    return 'http://192.168.3.7/img/Marcas/$m.png';
  }

  @override
  Widget build(BuildContext context) {
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
                          color: const Color(0xFFF6F8FF),

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
                          backgroundColor: const Color(0xFFE3E7FF),
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

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        Icon(icon, size: 18, color: const Color(0xFF9A93AD)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF7D7690),
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
