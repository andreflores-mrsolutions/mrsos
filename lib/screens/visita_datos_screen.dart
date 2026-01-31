import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/visita_service.dart';

class VisitaDatosScreen extends StatefulWidget {
  const VisitaDatosScreen({
    super.key,
    required this.tiId,
    required this.ticket,
  });
  final int tiId;
  final Map<String, dynamic> ticket;

  @override
  State<VisitaDatosScreen> createState() => _VisitaDatosScreenState();
}

class _VisitaDatosScreenState extends State<VisitaDatosScreen> {
  static const purple = Color(0xFF4F46E5);
  static const cardBg = Colors.white;

  final _folioCtrl = TextEditingController();
  final _comentCtrl = TextEditingController();

  File? _file;
  bool _saving = false;

  String _s(dynamic v) => (v ?? '').toString();

  @override
  void initState() {
    super.initState();
    // si ya hay folio en ticket, precargar
    final folio = _s(widget.ticket['tiFolioEntrada']).trim();
    if (folio.isNotEmpty) _folioCtrl.text = folio;
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;
    setState(() => _file = File(path));
  }

  Future<void> _submit() async {
    final folio = _folioCtrl.text.trim();
    if (folio.isEmpty) {
      _toast('Ingresa el folio de entrada');
      return;
    }

    setState(() => _saving = true);
    try {
      await VisitaService.I.guardarFolio(
        tiId: widget.tiId,
        folio: folio,
        coment: _comentCtrl.text.trim(),
        archivo: _file,
      );
      if (mounted) {
        _toast('Folio cargado correctamente');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;

    final eqModelo = _s(t['eqModelo']).trim();
    final eqVersion = _s(t['eqVersion']).trim();
    final equipo = eqVersion.isEmpty ? eqModelo : '$eqModelo $eqVersion';
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
          'Datos para Visita',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          children: [
            // Avatar + nombre (si lo tienes)
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

            _card(
              icon: Icons.badge_rounded,
              label: 'Folio de entrada',
              valueWidget: TextField(
                controller: _folioCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej. JFDKLL-12',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _card(
              icon: Icons.upload_file_rounded,
              label: 'Imagen de Acceso',
              value: 'Subir Archivo',
              trailing: _miniBtn('Seleccionar Archivos', onTap: _pickFile),
              footer:
                  'Se puede subir un QR o PDF con folio de acceso (opcional).',
            ),
            if (_file != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Archivo: ${_file!.path.split('/').last}',
                  style: TextStyle(
                    color: Colors.black.withOpacity(.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            _bigBtn('Cargar Folio de Visita', onTap: _saving ? null : _submit),
            const SizedBox(height: 14),

            // Equipo del ticket
            if (equipo.isNotEmpty || marca.isNotEmpty)
              _simpleInfoCard(
                title: equipo.isEmpty ? 'Equipo' : equipo,
                subtitle: marca,
              ),

            const SizedBox(height: 12),

            // Datos adicionales (coment)
            _card(
              icon: Icons.notes_rounded,
              label: 'Notas adicionales',
              valueWidget: TextField(
                controller: _comentCtrl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '(Opcional)',
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón extra placeholder (luego: INE)
            _softBtn(
              'Descargar INE',
              onTap: () {
                _toast('Esto lo conectamos en el siguiente paso.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
    Widget? trailing,
    String? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
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
                    valueWidget ??
                        Text(
                          value ?? '',
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

  Widget _simpleInfoCard({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
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

  Widget _miniBtn(String text, {required VoidCallback onTap}) {
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

  Widget _bigBtn(String text, {required VoidCallback? onTap}) {
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

  Widget _softBtn(String text, {required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEDE9FF),
          foregroundColor: const Color(0xFF1F2937),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
