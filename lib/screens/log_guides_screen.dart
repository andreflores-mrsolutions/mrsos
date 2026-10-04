import 'package:flutter/material.dart';
import '../services/app_http.dart';
import '../services/document_service.dart';
import '../services/log_guides_service.dart';
import '../widget/mr_components.dart';
import '../widget/mr_theme.dart';

class LogGuidesScreen extends StatefulWidget {
  const LogGuidesScreen({super.key, this.peId});
  final int? peId;
  @override
  State<LogGuidesScreen> createState() => _LogGuidesScreenState();
}

class _LogGuidesScreenState extends State<LogGuidesScreen> {
  List<Map<String, dynamic>> _guides = [];
  bool _loading = true;
  bool _opening = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await LogGuidesService(
        AppHttp.I.dio,
      ).list(peId: widget.peId);
      if (mounted) setState(() => _guides = rows);
    } catch (e) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> guide) async {
    setState(() => _opening = true);
    try {
      final id = int.tryParse('${guide['lgId']}');
      if (id == null || id <= 0) throw StateError('Guía inválida.');
      await DocumentService.openPdf(
        'dashboard/api/log_guides_download.php?lgId=$id',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppHttp.friendlyError(e))));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guías de logs')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const MRPageIntro(
            eyebrow: 'Centro de ayuda',
            title: 'Extrae tus logs.',
            subtitle: 'Guías disponibles para los equipos de tu cuenta.',
          ),
          const SizedBox(height: 20),
          if (_loading || _opening) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ] else if (!_loading && _guides.isEmpty)
            const MREmptyState(
              title: 'Sin guías publicadas',
              message:
                  'Contacta a soporte para obtener ayuda con la extracción.',
              icon: Icons.menu_book_outlined,
            )
          else
            ..._guides.map(
              (g) => Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text('${g['title'] ?? 'Guía de logs'}'),
                  subtitle: Text(
                    '${g['brand'] ?? ''}\n${g['description'] ?? ''}',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: _opening ? null : () => _open(g),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
