import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_http.dart';
import '../services/schedule_service.dart';
import '../services/session_store.dart';
import '../widget/mr_theme.dart';
import 'visita_datos_screen.dart';
import 'meeting_confirmation_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.ticketId,
    required this.visit,
    this.ticket = const {},
  });
  final int ticketId;
  final bool visit;
  final Map<String, dynamic> ticket;
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final _api = ScheduleService(AppHttp.I.dio);
  final _platform = TextEditingController(text: 'Google Meet');
  final _link = TextEditingController();
  final _reason = TextEditingController();
  final List<DateTime?> _starts = [null, null, null];
  Map<String, dynamic> _data = {};
  String _role = '';
  String? _error;
  bool _loading = true, _saving = false;
  late int _minutes = widget.visit ? 120 : 30;
  bool get _internal => ['MRSA', 'MRA', 'MRV'].contains(_role);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _platform.dispose();
    _link.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await SessionStore().getProfile();
      final data = await _api.load(widget.ticketId, visit: widget.visit);
      if (!mounted) return;
      setState(() {
        _data = data;
        _role = '${profile['usRol'] ?? ''}';
      });
    } catch (error) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(int index) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _starts[index] ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (!mounted || time == null) return;
    setState(
      () =>
          _starts[index] = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
    );
  }

  Future<void> _save() async {
    if (_saving || _starts.any((d) => d == null)) return;
    final link = Uri.tryParse(_link.text.trim());
    if (_link.text.trim().isNotEmpty &&
        (link == null || link.scheme != 'https' || link.host.isEmpty)) {
      setState(() => _error = 'Usa un enlace HTTPS válido para la reunión.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.propose(
        ticketId: widget.ticketId,
        visit: widget.visit,
        internal: _internal,
        starts: _starts.cast<DateTime>(),
        minutes: _minutes,
        platform: _platform.text.trim(),
        link: _link.text.trim(),
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Propuestas enviadas al sistema MRSoS.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _accept(Map proposal) async {
    if (_saving || _role == 'MRV') return;
    Map<String, String>? meeting;
    if (!widget.visit) {
      meeting = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (_) => MeetingConfirmationScreen(proposal: proposal),
        ),
      );
      if (!mounted || meeting == null) return;
    }
    setState(() => _saving = true);
    try {
      final result = await _api.accept(
        int.parse('${proposal[widget.visit ? 'vpId' : 'mpId']}'),
        visit: widget.visit,
        platform: meeting?['platform'] ?? '',
        link: meeting?['link'] ?? '',
        delivery: meeting?['delivery'] ?? 'link',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Horario confirmado.')));
      if (meeting?['delivery'] == 'email') {
        final recipients =
            (result['emailRecipients'] as List? ?? [])
                .whereType<String>()
                .where(
                  (e) => RegExp(r'^[^\s@,]+@[^\s@,]+\.[^\s@,]+$').hasMatch(e),
                )
                .toList();
        await showDialog<void>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Falta enviar la invitación'),
                content: SelectableText(
                  'El horario ya está confirmado. Envía la invitación con su enlace a:\n${recipients.join('\n')}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                  if (recipients.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final uri = Uri(
                          scheme: 'mailto',
                          path: recipients.join(','),
                          query:
                              'subject=${Uri.encodeComponent('Invitación · Ticket #${widget.ticketId}')}&body=${Uri.encodeComponent('Reunión en ${meeting?['platform']} el ${result['fecha']} a las ${result['hora']}.\nEnlace: ')}',
                        );
                        final opened = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (context.mounted && !opened)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No hay una app de correo disponible. Copia los destinatarios.',
                              ),
                            ),
                          );
                      },
                      child: const Text('Abrir borrador'),
                    ),
                ],
              ),
        );
      }
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposals = (_data['propuestas'] as List? ?? []).whereType<Map>();
    final info =
        _data[widget.visit ? 'visita' : 'meet'] is Map
            ? _data[widget.visit ? 'visita' : 'meet'] as Map
            : <String, dynamic>{};
    final accepted =
        _data['accepted'] is Map ? _data['accepted'] as Map : const {};
    final url =
        '${accepted['mpLink'] ?? info['enlace'] ?? widget.ticket['tiMeetEnlace'] ?? ''}';
    final canPropose = _role == 'CLI' || _role == 'MRA' || _role == 'MRSA';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.visit ? 'Coordinar visita' : 'Coordinar reunión'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                'Ticket #${widget.ticketId}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('Reintentar consulta'),
                ),
              ],
              if (!_loading && _data.isNotEmpty) ...[
                Text(
                  'Estado: ${info['estado'] ?? info['tiVisitaEstado'] ?? 'Sin programar'}',
                ),
                if (accepted.isNotEmpty)
                  Text(
                    'Horario confirmado: ${accepted['mpInicio'] ?? accepted['vpInicio']}',
                  ),
                if (!widget.visit && url.startsWith('https://'))
                  TextButton.icon(
                    onPressed: () async {
                      await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.video_call),
                    label: const Text('Abrir enlace de reunión'),
                  ),
                for (final proposal in proposals)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: MRSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${proposal['mpInicio'] ?? proposal['vpInicio'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Hasta ${proposal['mpFin'] ?? proposal['vpFin'] ?? ''}',
                          ),
                          Text(
                            '${proposal['mpEstado'] ?? proposal['vpEstado'] ?? ''}',
                          ),
                          if ((proposal['mpEstado'] ?? proposal['vpEstado']) ==
                                  'pendiente' &&
                              canPropose &&
                              '${_data['autorTipo']}' ==
                                  (_internal ? 'cliente' : 'ingeniero'))
                            TextButton(
                              onPressed:
                                  _saving ? null : () => _accept(proposal),
                              child: const Text('Confirmar este horario'),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (widget.visit) ...[
                  const SizedBox(height: 16),
                  for (final engineer
                      in (_data['ingenieros'] as List? ?? []).whereType<Map>())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.engineering),
                      title: Text('${engineer['nombre'] ?? 'Ingeniero'}'),
                      subtitle: Text(
                        '${engineer['usTelefono'] ?? ''} · ${engineer['usCorreo'] ?? ''}',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => VisitaDatosScreen(
                                tiId: widget.ticketId,
                                ticket: {
                                  ...widget.ticket,
                                  ...Map<String, dynamic>.from(info),
                                },
                              ),
                        ),
                      );
                      if (mounted) await _load();
                    },
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Folio y datos de acceso'),
                  ),
                ],
                if (canPropose &&
                    accepted.isEmpty &&
                    info['estado'] != 'confirmado' &&
                    info['tiVisitaConfirmada'] != 1) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Proponer tres horarios',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  const Text(
                    'Se comparten con la web. Elige tres alternativas distintas. Captura los horarios acordados con la sede; se envían sin conversión de zona horaria.',
                  ),
                  const SizedBox(height: 12),
                  if (!widget.visit) ...[
                    TextField(
                      controller: _platform,
                      decoration: const InputDecoration(
                        labelText: 'Plataforma',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _link,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Enlace HTTPS (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: _minutes,
                    decoration: const InputDecoration(labelText: 'Duración'),
                    items:
                        [30, 60, 120, 240]
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n minutos'),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _internal && !widget.visit
                            ? null
                            : (n) => setState(() => _minutes = n ?? 30),
                  ),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _pick(i),
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          _starts[i] == null
                              ? 'Elegir opción ${i + 1}'
                              : '${_starts[i]}'.substring(0, 16),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        _saving || _starts.any((d) => d == null) ? null : _save,
                    child: Text(_saving ? 'Enviando…' : 'Enviar propuestas'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
