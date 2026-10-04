import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/app_http.dart';
import '../services/chat_service.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, this.dio});
  final Dio? dio;
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final _service = ChatService(widget.dio ?? AppHttp.I.dio);
  List<Map<String, dynamic>> _chats = [];
  String _query = '';
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final chats = await _service.list();
      if (mounted) setState(() => _chats = chats);
    } catch (e) {
      if (mounted) setState(() => _error = AppHttp.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats =
        _chats
            .where(
              (e) => [
                e['folio'],
                e['client'],
                e['site'],
                e['equipment'],
                e['serial'],
                e['userName'],
                e['userEmail'],
              ].join(' ').toLowerCase().contains(_query.trim().toLowerCase()),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar folio, equipo o SN',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (!_busy && chats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay conversaciones activas. Puedes iniciar una desde el detalle de un ticket.',
                      ),
                    ),
                  for (final chat in chats)
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.forum_outlined),
                      ),
                      title: Text(
                        '${chat['folio']} · ${chat['equipment'] ?? ''}',
                      ),
                      subtitle: Text(
                        '${chat['client'] ?? ''}\n${chat['site'] ?? ''} · SN ${chat['serial'] ?? ''}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final id = int.tryParse('${chat['tiId']}');
                        if (id == null) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => TicketChatScreen(
                                  tiId: id,
                                  folio: '${chat['folio']}',
                                  dio: widget.dio,
                                ),
                          ),
                        );
                        if (mounted) _load();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TicketChatScreen extends StatefulWidget {
  const TicketChatScreen({
    super.key,
    required this.tiId,
    this.folio = '',
    this.dio,
  });
  final int tiId;
  final String folio;
  final Dio? dio;
  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen>
    with WidgetsBindingObserver {
  late final Dio _dio = widget.dio ?? AppHttp.I.dio;
  late final _service = ChatService(_dio);
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  String _role = '';
  String _myId = '';
  int? _activeThreadId;
  bool _needsAction = false;
  bool _loading = false, _sending = false, _ready = false, _uncertain = false;
  bool _foreground = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_foreground && ModalRoute.of(context)?.isCurrent == true && !_sending)
        _load(quiet: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && ModalRoute.of(context)?.isCurrent == true)
      _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (!quiet) _error = null;
    });
    try {
      final me = AppHttp.jsonMap((await _dio.get('/me.php')).data);
      final data = await _service.thread(widget.tiId);
      if (!mounted) return;
      final unique = <String, Map<String, dynamic>>{};
      for (final row in (data['messages'] as List? ?? []).whereType<Map>()) {
        unique['${row['id']}'] = Map<String, dynamic>.from(row);
      }
      final changed = unique.length != _messages.length;
      setState(() {
        _role = '${me['usRol'] ?? me['rol'] ?? ''}';
        _myId = '${me['usId']}';
        _activeThreadId = int.tryParse('${data['activeTaId']}');
        _needsAction = data['needsAction'] == true;
        _messages = unique.values.toList();
        _ready = true;
        _error = null;
      });
      if (changed)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients)
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = AppHttp.friendlyError(e);
          _ready = false;
        });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (!_ready || _sending || _uncertain || !ChatService.canSend(_role))
      return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.send(
        widget.tiId,
        _text.text,
        role: _role,
        activeThreadId: _activeThreadId,
      );
      _text
          .clear(); // POST committed: a subsequent GET failure must not restore the draft.
      await _load();
    } catch (e) {
      if (mounted)
        setState(() {
          _uncertain =
              e is DioException &&
              (e.response == null || (e.response?.statusCode ?? 0) >= 500);
          _error =
              _uncertain
                  ? 'No se pudo confirmar el envío. Actualiza y revisa la conversación antes de intentar enviarlo otra vez.'
                  : AppHttp.friendlyError(e);
        });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Chat · ${widget.folio.isEmpty ? '#${widget.tiId}' : widget.folio}',
      ),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Actualizar conversación',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_ready && _needsAction)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Esta conversación requiere tu respuesta.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_uncertain && !_loading)
            TextButton(
              onPressed: () async {
                await _load();
                if (!context.mounted || !_ready) return;
                final retry = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('¿El mensaje no aparece?'),
                        content: const Text(
                          'Comprueba el historial para evitar un envío duplicado.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Ya aparece'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('No aparece; habilitar envío'),
                          ),
                        ],
                      ),
                );
                if (!mounted || retry == null) return;
                setState(() {
                  _uncertain = false;
                  if (!retry) _text.clear();
                });
              },
              child: const Text('Revisar el envío pendiente'),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                if (_ready && _messages.isEmpty)
                  const Text('Inicia la conversación sobre este ticket.'),
                for (final message in _messages)
                  Align(
                    alignment:
                        '${message['authorId']}' == _myId
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        color:
                            '${message['authorId']}' == _myId
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${message['authorName'] ?? 'Usuario'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText('${message['message'] ?? ''}'),
                              const SizedBox(height: 8),
                              Text(
                                _date('${message['createdAt'] ?? ''}'),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_ready && !ChatService.canSend(_role))
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Tu rol sólo permite consultar esta conversación.'),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _text,
                    enabled: _ready && !_sending && !_uncertain,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje al equipo de soporte',
                      helperText:
                          'No compartas contraseñas ni códigos de acceso.',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          !_ready || _sending || _uncertain ? null : _send,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(_sending ? 'Enviando…' : 'Enviar mensaje'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
  String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
