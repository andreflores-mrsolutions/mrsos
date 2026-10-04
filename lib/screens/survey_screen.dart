import 'package:flutter/material.dart';
import '../services/app_http.dart';
import '../services/document_service.dart';
import '../services/session_store.dart';
import '../services/survey_service.dart';
import '../widget/mr_theme.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({
    super.key,
    required this.ticketId,
    this.sheet = const {},
  });
  final int ticketId;
  final Map<String, dynamic> sheet;
  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _saving = false, _canSkip = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    SessionStore().getProfile().then((profile) {
      if (mounted) setState(() => _canSkip = profile['usRol'] == 'CLI');
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send({bool skip = false}) async {
    if (_saving) return;
    if (skip) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('¿Cerrar sin evaluación?'),
              content: const Text(
                'El ticket quedará cerrado en la app y en la web.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Volver'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Cerrar ticket'),
                ),
              ],
            ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = SurveyService(AppHttp.I.dio);
      if (skip) {
        await service.skip(widget.ticketId);
      } else {
        await service.submit(
          widget.ticketId,
          rating: _rating,
          comment: _comment.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skip
                ? 'Ticket cerrado sin evaluación.'
                : 'Gracias. Tu evaluación quedó registrada.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Evaluar el servicio')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MRSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket #${widget.ticketId}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text('¿Cómo fue tu experiencia con MRSoS?'),
                const Text(
                  'Tu evaluación se comparte con el sistema web y completa el cierre del caso.',
                ),
                const SizedBox(height: 16),
                if (widget.sheet['downloadUrl'] != null)
                  OutlinedButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : () async {
                              try {
                                await DocumentService.openPdf(
                                  '${widget.sheet['downloadUrl']}',
                                );
                              } catch (error) {
                                if (mounted)
                                  setState(
                                    () => _error = AppHttp.friendlyError(error),
                                  );
                              }
                            },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      'Hoja ${widget.sheet['hsFolio'] ?? 'de servicio'}',
                    ),
                  ),
                Wrap(
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      tooltip: '${index + 1} estrellas',
                      onPressed:
                          _saving
                              ? null
                              : () => setState(() => _rating = index + 1),
                      icon: Icon(
                        index < _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                      color: const Color(0xFFDA9900),
                      iconSize: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _comment,
                  maxLines: 4,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Comentario (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                FilledButton(
                  onPressed: _saving || _rating == 0 ? null : () => _send(),
                  child: Text(
                    _saving ? 'Guardando…' : 'Enviar evaluación y cerrar',
                  ),
                ),
                if (_canSkip)
                  TextButton(
                    onPressed: _saving ? null : () => _send(skip: true),
                    child: const Text('Omitir encuesta y cerrar ticket'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
