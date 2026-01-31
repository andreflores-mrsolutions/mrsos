import 'package:flutter/material.dart';
import '../services/visita_service.dart';

class VisitaProponerScreen extends StatefulWidget {
  const VisitaProponerScreen({
    super.key,
    required this.tiId,
    required this.ticket,
  });

  final int tiId;
  final Map<String, dynamic> ticket;

  @override
  State<VisitaProponerScreen> createState() => _VisitaProponerScreenState();
}

class _VisitaProponerScreenState extends State<VisitaProponerScreen> {
  static const purple = Color(0xFF4F46E5);

  DateTime _inicio = DateTime.now().add(const Duration(days: 2, hours: 2));
  DateTime _fin = DateTime.now().add(const Duration(days: 2, hours: 4));

  int _duracionMin = 60;
  bool _requiereAcceso = false;

  final _extraAccesoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  bool _saving = false;

  String _s(dynamic v) => (v ?? '').toString();

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: initial.isBefore(now) ? now : initial,
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickInicio() async {
    final dt = await _pickDateTime(_inicio);
    if (dt == null) return;

    setState(() {
      _inicio = dt;
      // si inicio queda después del fin, ajustamos fin automáticamente
      if (_fin.isBefore(_inicio)) {
        _fin = _inicio.add(Duration(minutes: _duracionMin));
      }
    });
  }

  Future<void> _pickFin() async {
    final dt = await _pickDateTime(_fin);
    if (dt == null) return;

    setState(() {
      _fin = dt;
      // si fin queda antes del inicio, lo corregimos
      if (_fin.isBefore(_inicio)) {
        _fin = _inicio.add(Duration(minutes: _duracionMin));
      }
    });
  }

  void _syncFinWithDuration() {
    setState(() {
      _fin = _inicio.add(Duration(minutes: _duracionMin));
    });
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (_duracionMin < 15) {
      _toast('La duración mínima es 15 minutos');
      return;
    }

    // Validación rango
    if (!_fin.isAfter(_inicio)) {
      _toast('La fecha final debe ser posterior a la inicial');
      return;
    }

    setState(() => _saving = true);
    try {
      await VisitaService.I.proponer(
        tiId: widget.tiId,
        inicio: _inicio,
        fin: _fin,
        duracionMin: _duracionMin,
        requiereAcceso: _requiereAcceso,
        extraAcceso: _extraAccesoCtrl.text.trim(),
      );

      if (!mounted) return;
      _toast('Visita propuesta');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _fmt(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;

    final eqModelo = _s(t['eqModelo']).trim();
    final eqVersion = _s(t['eqVersion']).trim();
    final equipo = (eqVersion.isEmpty) ? eqModelo : '$eqModelo $eqVersion';
    final marca = _s(t['maNombre']).trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Proponer Visita',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          children: [
            // Avatar / header
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 48,
                color: purple.withOpacity(.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _s(t['usNombre']).isEmpty ? 'Usuario' : _s(t['usNombre']),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            if (equipo.isNotEmpty || marca.isNotEmpty) ...[
              _infoCard(
                title: equipo.isEmpty ? 'Equipo' : equipo,
                subtitle: marca,
              ),
              const SizedBox(height: 12),
            ],

            // Fecha inicial
            _card(
              icon: Icons.calendar_month_rounded,
              label: 'Fecha Inicial',
              value: _fmt(_inicio),
              trailing: _chipBtn('Seleccionar fecha', onTap: _pickInicio),
            ),
            const SizedBox(height: 12),

            // Fecha final
            _card(
              icon: Icons.calendar_month_rounded,
              label: 'Fecha Final',
              value: _fmt(_fin),
              trailing: _chipBtn('Seleccionar fecha', onTap: _pickFin),
            ),
            const SizedBox(height: 12),

            // Duración (y ajusta fin automáticamente)
            _card(
              icon: Icons.access_time_rounded,
              label: 'Tiempo estimado',
              value: '$_duracionMin min',
              trailing: _durationPicker(onChanged: _syncFinWithDuration),
              footer: 'Tiempo de Duración de la visita en Minutos',
            ),
            const SizedBox(height: 12),

            _checkRow(
              text:
                  'El Ingeniero en soporte enviará información sobre el folio de la visita para garantizar el acceso.',
              checked: _requiereAcceso,
              onChanged: (v) => setState(() => _requiereAcceso = v),
            ),
            const SizedBox(height: 12),

            _textCard(
              icon: Icons.badge_rounded,
              label: 'Datos Adicionales',
              controller: _extraAccesoCtrl,
              hint: '(Opcional) Ej. Persona contacto, requisitos, caseta, etc.',
            ),
            const SizedBox(height: 12),

            _textCard(
              icon: Icons.notes_rounded,
              label: 'Notas Adicionales',
              controller: _notasCtrl,
              hint: '(Opcional)',
            ),
            const SizedBox(height: 16),

            _primaryBtn('Proponer Visita', onTap: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }

  // ---------- UI helpers ----------

  Widget _infoCard({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.black.withOpacity(.6),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
    String? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: purple),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.black.withOpacity(.55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                footer,
                style: TextStyle(
                  color: Colors.black.withOpacity(.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _textCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: purple),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black.withOpacity(.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkRow({
    required String text,
    required bool checked,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            activeColor: purple,
            onChanged: (v) => onChanged(v ?? false),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.black.withOpacity(.7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipBtn(String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(color: purple, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _durationPicker({required VoidCallback onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, color: purple),
            onPressed: () {
              setState(
                () => _duracionMin = (_duracionMin - 15).clamp(15, 24 * 60),
              );
              onChanged();
            },
          ),
          Text(
            '$_duracionMin',
            style: const TextStyle(color: purple, fontWeight: FontWeight.w900),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: purple),
            onPressed: () {
              setState(
                () => _duracionMin = (_duracionMin + 15).clamp(15, 24 * 60),
              );
              onChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _primaryBtn(String text, {required VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child:
            _saving
                ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
      ),
    );
  }
}
