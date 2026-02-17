import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_http.dart';

class SubirLogsScreen extends StatefulWidget {
  const SubirLogsScreen({
    super.key,
    required this.tiId,
    required this.marca,
    required this.modelo,
    this.supportEmail = 'soporte@mrsolutions.com.mx',
  });

  final int tiId;
  final String marca;
  final String modelo;
  final String supportEmail;

  @override
  State<SubirLogsScreen> createState() => _SubirLogsScreenState();
}

class _SubirLogsScreenState extends State<SubirLogsScreen> {
  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);
  static const Color accent = Color(0xFF4B3CFF); // morado/azul del UI
  static const Color soft = Color(0xFFF1F0FF);
  static const Color soft2 = Color(0xFFF6F7FF);
  static const Color textMuted = Color(0xFF6B667A);

  final List<PlatformFile> _files = [];
  bool _uploading = false;

  String _s(String v) => v.trim();

  String get _helpUrl {
    final marca = Uri.encodeComponent(_s(widget.marca));
    final modelo = Uri.encodeComponent(_s(widget.modelo));
    return 'http://192.168.3.7/ayuda/ayuda_logs.php?marca=$marca&modelo=$modelo';
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['log', 'txt', 'zip', '7z', 'rar'],
      withData: false,
    );

    if (!mounted) return;

    if (res == null || res.files.isEmpty) return;

    setState(() {
      _files
        ..clear()
        ..addAll(res.files.where((f) => (f.path ?? '').isNotEmpty));
    });
  }

  void _removeFileAt(int idx) {
    setState(() => _files.removeAt(idx));
  }

  Future<void> _upload() async {
    if (_files.isEmpty) {
      _toast('Selecciona al menos un archivo.');
      return;
    }

    setState(() => _uploading = true);

    try {
      final dio = AppHttp.I.dio;

      for (final f in _files) {
        final path = f.path!;
        final form = FormData.fromMap({
          'tiId': widget.tiId.toString(),
          'logs': await MultipartFile.fromFile(
            path,
            filename: f.name,
          ), // 👈 logs (no logs[])
        });

        final r = await dio.post(
          '/subir_logs.php',
          data: form,
          options: Options(
            contentType: 'multipart/form-data',
            sendTimeout: const Duration(seconds: 90),
            receiveTimeout: const Duration(seconds: 90),
          ),
        );

        final data = (r.data is Map) ? Map<String, dynamic>.from(r.data) : {};
        final ok = data['success'] == true;

        if (!ok) {
          final err =
              (data['error'] ?? data['message'] ?? 'Error al subir logs')
                  .toString();
          _toast(err);
          return;
        }
      }

      _toast('Logs enviados correctamente.');
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      // 🔥 debug REAL: aquí sabrás si fue red/timeout/url
      final sc = e.response?.statusCode;
      final body = e.response?.data;
      _toast('Error red/servidor: ${e.type} (${sc ?? "sin status"})');

      debugPrint('DIO ERROR type=${e.type} message=${e.message}');
      debugPrint('DIO ERROR url=${e.requestOptions.uri}');
      debugPrint('DIO ERROR status=$sc');
      debugPrint('DIO ERROR data=$body');
      debugPrint('DIO ERROR err=${e.error}');
    } catch (e) {
      _toast('Error inesperado al subir logs.');
      debugPrint('UPLOAD ERROR: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openHelp() async {
    final uri = Uri.parse(_helpUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('No se pudo abrir la ayuda.');
    }
  }

  Future<void> _sendMail() async {
    final subject = Uri.encodeComponent(
      'Ayuda con extracción/envío de Logs - Ticket ${widget.tiId}',
    );
    final body = Uri.encodeComponent(
      'Hola MR Solutions,\n\n'
      'Necesito ayuda con la extracción/envío de logs para el Ticket ${widget.tiId}.\n'
      'Equipo: ${widget.marca} - ${widget.modelo}\n\n'
      'Gracias.',
    );

    final uri = Uri.parse(
      'mailto:${widget.supportEmail}?subject=$subject&body=$body',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('No se pudo abrir la app de correo.');
    }
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(ClipboardData(text: widget.supportEmail));
    _toast('Correo copiado: ${widget.supportEmail}');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleModelo = _s(widget.modelo).isEmpty ? 'Equipo' : widget.modelo;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const Expanded(
                  child: Text(
                    'Cargar Logs',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),

            // Card: Subir Logs
            _CardShell(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.file_upload_outlined,
                      color: mrPurple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Logs',
                          style: TextStyle(
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Subir Logs',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _uploading ? null : _pickFiles,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: soft,
                        foregroundColor: accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text(
                        'Seleccionar Archivos',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              'Acepta .log, .txt o comprimidos (.zip/.7z/.rar).',
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w500),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 12),

            // Lista de archivos seleccionados
            if (_files.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: soft2,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_file_rounded,
                          size: 18,
                          color: mrPurple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Archivos seleccionados (${_files.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: mrPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_files.length, (i) {
                      final f = _files[i];
                      final sizeKb = (f.size / 1024).toStringAsFixed(1);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE6E6F2)),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          title: Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '$sizeKb KB',
                            style: const TextStyle(
                              color: textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: IconButton(
                            onPressed:
                                _uploading ? null : () => _removeFileAt(i),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Botón principal: Enviar Logs
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _uploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child:
                    _uploading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Enviar Logs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 12),

            // ¿Cómo extraer los logs?
            _SoftButton(text: '¿Cómo extraer los logs?', onTap: _openHelp),

            const SizedBox(height: 10),
            Text(
              'Se te redireccionará a tu aplicación de navegador predeterminado\n'
              'para poder descargar un PDF con los pasos a seguir en la\n'
              'extracción de Logs según el equipo del ticket abierto.\n\n'
              'Equipo: ${widget.marca} · $titleModelo',
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: textMuted,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 14),

            // Pedir ayuda por correo
            _SoftButton(text: 'Pedir ayuda por correo', onTap: _sendMail),
            const SizedBox(height: 10),

            // Correo + copiar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _copyEmail,
                  child: Text(
                    widget.supportEmail,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _copyEmail,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.copy_rounded, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Se te redireccionará a tu aplicación de correo predeterminada\n'
              'para poder hacer seguimiento de logs por correo y se notificará al\n'
              'ingeniero asignado para proporcionar ayuda mediante email.',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: textMuted,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 14),

            // Solicitar reunión virtual (por ahora NO lo hacemos, lo dejamos UI listo)
            _SoftButton(
              text: 'Solicitar una Reunión Virtual',
              onTap: () {
                _toast('Esta opción la activamos en la siguiente fase (Meet).');
              },
            ),

            const SizedBox(height: 10),
            const Text(
              'El equipo de MRSolutions te ayudará con la extracción de los logs a\n'
              'través de la plataforma que desees de reuniones virtuales (Google\n'
              'Meet, Teams, etc).',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: textMuted,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  static const Color soft = Color(0xFFF1F0FF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: soft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 54,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
