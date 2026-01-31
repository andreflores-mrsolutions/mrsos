import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../services/visita_service.dart';

class VisitaAsignarScreen extends StatefulWidget {
  const VisitaAsignarScreen({
    super.key,
    required this.tiId,
    required this.ticket,
  });

  final int tiId;
  final Map<String, dynamic> ticket;

  @override
  State<VisitaAsignarScreen> createState() => _VisitaAsignarScreenState();
}

class _VisitaAsignarScreenState extends State<VisitaAsignarScreen> {
  static const purple = Color(0xFF4F46E5);

  DateTime _fechaHora = DateTime.now().add(const Duration(days: 1, hours: 2));
  int _duracionMin = 60;

  bool _requiereAcceso = false;

  final _extraAccesoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  bool _saving = false;

  String _s(dynamic v) => (v ?? '').toString();
  static const _host = 'https://yellow-chicken-910471.hostingersite.com';

  String _urlIngSvg(int usIdIng) => '$_host/img/Ingeniero/$usIdIng.svg';

  // Opciones para marca/equipo: si tu API ya trae URLs úsala, si no, intentamos por nombre o id.
  String _urlMarca(Map<String, dynamic> t) {
    final u = _s(t['maNombre']).trim();
    print(u);
    if (u.isNotEmpty) return u.startsWith('http') ? u : '$_host/$u';

    final id = _s(t['eqModelo']).trim();
    if (id.isNotEmpty) return '$_host/img/Marcas/$id.png';
    print(id);
    final nombre = _s(t['maNombre']).trim();
    if (nombre.isNotEmpty) return '$_host/img/Marcas/$nombre.png';

    return '';
  }

  String _urlEquipo(Map<String, dynamic> t) {
    final u = _s(t['maNombre']).trim();

    final id = _s(t['eqNombre']).trim();
    final modelo = _s(t['eqModelo']).trim();
    if (u.isNotEmpty) {
      print(modelo);
      return u.startsWith('http') ? u : '$_host/img/Equipos/$u/$modelo.png';
    }
    if (id.isNotEmpty) return '$_host/img/Equipo/$modelo/$id.png';

    return '';
  }

  Future<void> _pickFechaHora() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: _fechaHora.isBefore(now) ? now : _fechaHora,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora),
    );
    if (time == null) return;

    setState(() {
      _fechaHora = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_saving) return;

    // Validación rápida
    if (_duracionMin < 15) {
      _toast('La duración mínima es 15 minutos');
      return;
    }

    setState(() => _saving = true);
    try {
      await VisitaService.I.asignar(
        tiId: widget.tiId,
        fechaHora: _fechaHora,
        duracionMin: _duracionMin,
        requiereAcceso: _requiereAcceso,
        extraAcceso: _extraAccesoCtrl.text.trim(),
      );

      if (!mounted) return;
      _toast('Visita asignada');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _imgCircle(String url, {required IconData fallbackIcon}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          (url.isEmpty)
              ? Icon(fallbackIcon, color: purple.withOpacity(.7))
              : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        Icon(fallbackIcon, color: purple.withOpacity(.7)),
              ),
    );
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _fmtFechaHora(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    final dd = two(d.day);
    final mm = two(d.month);
    final yy = d.year.toString();
    final hh = two(d.hour);
    final mi = two(d.minute);
    return '$dd/$mm/$yy  $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;

    final eqModelo = _s(t['eqModelo']).trim();
    final eqVersion = _s(t['eqVersion']).trim();
    final equipo = (eqVersion.isEmpty) ? eqModelo : '$eqModelo $eqVersion';
    final marca = _s(t['maNombre']).trim();
    final usIdIng = int.tryParse(_s(t['usIdIng'])) ?? 0;

    // si tu backend trae nombre del ingeniero en otra key, úsala aquí.
    // (ej: usNombreIng, ingNombre, etc). Si no, dejamos fallback.
    final ingNombre =
        _s(t['usNombreIng']).isNotEmpty
            ? _s(t['usNombreIng'])
            : (usIdIng > 0
                ? 'Ingeniero asignado #$usIdIng'
                : 'Ingeniero asignado');

    final marcaUrl = _urlMarca(t);
    final equipoUrl = _urlEquipo(t);

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
          'Asignar Visita',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          children: [
            // Avatar / header
            // Header Ingeniero
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFF3F4F6),
                    child:
                        (usIdIng > 0)
                            ? ClipOval(
                              child: SvgPicture.network(
                                _urlIngSvg(usIdIng),
                                width: 46,
                                height: 46,
                                placeholderBuilder:
                                    (_) => Icon(
                                      Icons.person,
                                      color: purple.withOpacity(.7),
                                    ),
                              ),
                            )
                            : Icon(Icons.person, color: purple.withOpacity(.7)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ingeniero asignado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ingNombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Card equipo + marca con imágenes
            if (equipo.isNotEmpty || marca.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _imgCircle(marcaUrl, fallbackIcon: Icons.apartment_rounded),
                    const SizedBox(width: 10),
                    _imgCircle(equipoUrl, fallbackIcon: Icons.memory_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            equipo.isEmpty ? 'Equipo' : equipo,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            marca,
                            style: TextStyle(
                              color: Colors.black.withOpacity(.6),
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Text(
              _s(t['usNombre']).isEmpty ? 'Usuario' : _s(t['usNombre']),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            // Equipo del ticket (opcional, ayuda al contexto)
            if (equipo.isNotEmpty || marca.isNotEmpty) ...[
              _infoCard(
                title: equipo.isEmpty ? 'Equipo' : equipo,
                subtitle: marca,
              ),
              const SizedBox(height: 12),
            ],

            // Fecha / Hora
            _card(
              icon: Icons.calendar_month_rounded,
              label: 'Fecha y hora',
              value: _fmtFechaHora(_fechaHora),
              trailing: _chipBtn('Seleccionar fecha', onTap: _pickFechaHora),
            ),
            const SizedBox(height: 12),

            // Duración
            _card(
              icon: Icons.access_time_rounded,
              label: 'Tiempo estimado',
              value: '$_duracionMin min',
              trailing: _durationPicker(),
              footer: 'Tiempo de Duración de la visita en Minutos',
            ),
            const SizedBox(height: 12),

            // Checklist (texto igual a tu estilo)
            _checkRow(
              text:
                  'El Ingeniero en soporte enviará información sobre el folio de la visita para garantizar el acceso.',
              checked: _requiereAcceso,
              onChanged: (v) => setState(() => _requiereAcceso = v),
            ),
            const SizedBox(height: 12),

            // Datos adicionales (acceso)
            _textCard(
              icon: Icons.badge_rounded,
              label: 'Datos Adicionales',
              controller: _extraAccesoCtrl,
              hint: '(Opcional) Ej. Persona contacto, requisitos, caseta, etc.',
            ),
            const SizedBox(height: 12),

            // Notas adicionales
            _textCard(
              icon: Icons.notes_rounded,
              label: 'Notas Adicionales',
              controller: _notasCtrl,
              hint: '(Opcional)',
            ),
            const SizedBox(height: 16),

            _primaryBtn('Asignar Visita', onTap: _saving ? null : _submit),
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

  Widget _durationPicker() {
    // Selector simple como tu estilo: botones +/- y valor
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
            onPressed:
                () => setState(
                  () => _duracionMin = (_duracionMin - 15).clamp(15, 24 * 60),
                ),
          ),
          Text(
            '$_duracionMin',
            style: const TextStyle(color: purple, fontWeight: FontWeight.w900),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: purple),
            onPressed:
                () => setState(
                  () => _duracionMin = (_duracionMin + 15).clamp(15, 24 * 60),
                ),
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
