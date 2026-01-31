import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/app_http.dart';
import '../services/meet_service.dart';
import '../widget/mr_action_tile.dart';

class MeetCambiarScreen extends StatefulWidget {
  const MeetCambiarScreen({
    super.key,
    required this.tiId,
    required this.isMr,
    required this.meetActual, // pásale el mapa del ticket
  });

  final int tiId;
  final bool isMr;
  final Map<String, dynamic> meetActual;

  @override
  State<MeetCambiarScreen> createState() => _MeetCambiarScreenState();
}

class _MeetCambiarScreenState extends State<MeetCambiarScreen> {
  static const mrPurple = Color(0xFF200F4C);
  static const mrRed = Color(0xFFFF6B6B);
  static const textMuted = Color(0xFF6B667A);

  late final MeetService api;

  late DateTime _start;
  String _quienHara = 'cliente';
  String _plataforma = 'Google';
  final _linkCtrl = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    api = MeetService(dio: AppHttp.I.dio);

    // Del ticket
    final f = (widget.meetActual['tiMeetFecha'] ?? '').toString(); // YYYY-MM-DD
    final h = (widget.meetActual['tiMeetHora'] ?? '').toString(); // HH:MM:SS
    final plat = (widget.meetActual['tiMeetPlataforma'] ?? 'Google').toString();
    final link = (widget.meetActual['tiMeetEnlace'] ?? '').toString();
    final activo =
        (widget.meetActual['tiMeetActivo'] ?? '').toString().toLowerCase();

    _plataforma = plat.isEmpty ? 'Google' : plat;
    _linkCtrl.text = link;
    _quienHara = activo.contains('ingeniero') ? 'ingeniero' : 'cliente';

    _start = DateTime.now().add(const Duration(hours: 2));
    if (f.isNotEmpty && h.isNotEmpty) {
      final dt = DateTime.tryParse('$f $h');
      if (dt != null) _start = dt;
    }
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  bool get _linkRequired {
    final p = _plataforma.toLowerCase();
    return p.contains('teams') || p.contains('otra');
  }

  String _fmt(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:00';
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (t == null) return;

    setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _reprogramar() async {
    if (_linkRequired && _linkCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El link es obligatorio para Teams u Otra plataforma.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final fecha = _fmt(_start).substring(0, 10);
      final hora = _fmt(_start).substring(11, 19);

      final r = await api.reprogramar(
        tiId: widget.tiId,
        fecha: fecha,
        hora: hora,
        plataforma: _plataforma,
        link: _linkCtrl.text.trim(),
      );

      if (r['success'] == true) {
        if (mounted) Navigator.pop(context, true);
        return;
      }

      final err =
          (r['error'] ?? r['message'] ?? 'No se pudo reprogramar').toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.response?.statusCode ?? 'sin status'}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Eliminar Meet'),
            content: const Text(
              '¿Confirmas eliminar el meet? Esto puede afectar tiempos y SLA.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final r = await api.cancelar(
        tiId: widget.tiId,
        motivo: 'Cancelado desde app',
      );
      if (r['success'] == true) {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final err =
          (r['error'] ?? r['message'] ?? 'No se pudo eliminar').toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startStr = '${_fmt(_start)} (1h)';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const Expanded(
                  child: Text(
                    'Cambiar Reunión',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),

            MRActionTile(
              icon: Icons.calendar_month_rounded,
              subtitle: 'Fecha y Hora',
              title: startStr,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              onTap: _pickStart,
            ),

            const SizedBox(height: 14),
            const Text(
              'El cambio de hora y fecha estará disponible hasta 3hrs antes de la reunión.',
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 18),

            MRActionTile(
              icon: Icons.person_rounded,
              subtitle: '¿Quién hará el meet?',
              title:
                  _quienHara == 'ingeniero'
                      ? 'El ingeniero hará el meet'
                      : 'Yo haré el meet',
              trailing: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              onTap: () async {
                final v = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder:
                      (_) => _PickerSheet(
                        title: '¿Quién hará el meet?',
                        options: const [
                          ('cliente', 'Yo haré el meet'),
                          ('ingeniero', 'El ingeniero hará el meet'),
                        ],
                        selected: _quienHara,
                      ),
                );
                if (v != null) setState(() => _quienHara = v);
              },
            ),

            const SizedBox(height: 18),

            MRActionTile(
              icon: Icons.video_call_rounded,
              subtitle: 'Plataforma',
              title: _plataforma,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              onTap: () async {
                final v = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder:
                      (_) => _PickerSheet(
                        title: 'Plataforma',
                        options: const [
                          ('Google', 'Google'),
                          ('Teams', 'Teams'),
                          ('Otra plataforma', 'Otra plataforma'),
                        ],
                        selected: _plataforma,
                      ),
                );
                if (v != null) setState(() => _plataforma = v);
              },
            ),

            const SizedBox(height: 18),
            MRActionTile(
              icon: Icons.link_rounded,
              subtitle: 'Link de reunión',
              title: _linkRequired ? 'Link (obligatorio)' : 'Link (opcional)',
              trailing: const Icon(Icons.edit_rounded, size: 20),
              onTap: () async {
                final v = await showDialog<String>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: const Text('Link de reunión'),
                        content: TextField(
                          controller: _linkCtrl,
                          decoration: InputDecoration(
                            hintText: 'https://...',
                            helperText:
                                _linkRequired ? 'Obligatorio' : 'Opcional',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.pop(context, _linkCtrl.text),
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                );
                if (v != null) setState(() {});
              },
            ),

            const SizedBox(height: 22),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _reprogramar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mrPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _loading ? 'Procesando...' : 'Reprogramar reunión',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _eliminar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mrRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Eliminar Meet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            const Text(
              'Cambiar el meet puede cambiar los tiempos de solución del ticket y afectar los SLA indicados en póliza.\n\n'
              'Eliminar el meet puede cambiar los tiempos de solución del ticket y afectar los SLA indicados en póliza; además, eliminar el meet generará un tiempo de respuesta por parte del cliente de máximo 48hrs. '
              'De lo contrario el ticket se cerrará de forma automática.',
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<(String, String)> options;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final o in options)
              ListTile(
                title: Text(
                  o.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing:
                    (o.$1 == selected)
                        ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4F46E5),
                        )
                        : null,
                onTap: () => Navigator.pop(context, o.$1),
              ),
          ],
        ),
      ),
    );
  }
}
