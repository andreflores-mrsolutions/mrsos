import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/app_http.dart';
import '../services/notification_service.dart';
import '../services/session_store.dart';
import '../services/push_service.dart';
import '../theme/mrs_theme.dart';
import 'ticket_detail_screen.dart';
import 'tickets_sedes_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsService _service;
  List<InboxNotification> _items = const [];
  bool _loading = true;
  String _error = '';
  Map<String, dynamic> _delivery = {};

  @override
  void initState() {
    super.initState();
    _service = NotificationsService(dio: AppHttp.I.dio);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final items = await _service.list();
      Map<String, dynamic> delivery = {};
      try {
        delivery = AppHttp.jsonMap(
          (await AppHttp.I.dio.get('/notification_status.php')).data,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _delivery = delivery;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() {
        _items =
            _items
                .map(
                  (item) => item.copyWith(read: true, readAt: DateTime.now()),
                )
                .toList();
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _open(InboxNotification item) async {
    if (!item.read) {
      try {
        await _service.markRead(item.id);
        if (mounted) {
          setState(() {
            _items =
                _items
                    .map(
                      (value) =>
                          value.id == item.id
                              ? value.copyWith(
                                read: true,
                                readAt: DateTime.now(),
                              )
                              : value,
                    )
                    .toList();
          });
        }
      } catch (error) {
        _showError(error);
      }
    }
    if (!mounted) return;

    final ticketId = item.ticketId;
    if (ticketId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(tiId: ticketId, folio: ''),
        ),
      );
      return;
    }

    if (item.url.toLowerCase().contains('ticket')) {
      final profile = await SessionStore().getProfile();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => TicketsSedesScreen(
                usId: '${profile['usId'] ?? ''}',
                userName: '${profile['usNombre'] ?? 'Usuario'}',
              ),
        ),
      );
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
  }

  String _friendlyError(Object error) {
    final value = error.toString().replaceFirst('Bad state: ', '');
    if (value.contains('401') || value.toLowerCase().contains('autenticado')) {
      return 'Tu sesión expiró. Inicia sesión nuevamente.';
    }
    return value.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final unread = NotificationInbox.unreadCount.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAll,
              child: const Text(
                'Marcar todas',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: PushService.I.status,
                        builder: (_, text, __) => Text(text),
                      ),
                      if (_delivery['mobileConfigured'] == false)
                        const Text(
                          'El servidor todavía no tiene habilitado el envío Firebase.',
                          style: TextStyle(color: Colors.deepOrange),
                        ),
                      if (_delivery['mobileDatabaseReady'] == false)
                        const Text(
                          'El servidor no puede consultar la tabla de dispositivos.',
                        ),
                      if (_error.isNotEmpty && _items.isNotEmpty) Text(_error),
                      TextButton.icon(
                        onPressed: () async {
                          await PushService.I.sync(requestPermission: true);
                          if (mounted) await _load();
                        },
                        icon: const Icon(Icons.sync),
                        label: const Text('Verificar notificaciones'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: _InboxSummary(unread: unread, total: _items.length),
                ),
              ),
              if (_loading && _items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error.isNotEmpty && _items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(message: _error, onRetry: _load),
                )
              else if (_items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  sliver: SliverList.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _NotificationCard(
                        item: item,
                        onTap: () => _open(item),
                      );
                    },
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: OutlinedButton.icon(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => const UserProfileScreen(
                                  baseUrl: AppConfig.apiBaseUrl,
                                ),
                          ),
                        ),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configurar tipos de aviso'),
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

class _InboxSummary extends StatelessWidget {
  const _InboxSummary({required this.unread, required this.total});

  final int unread;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MRSTheme.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24200F4C),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.notifications_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0 ? 'Todo al día' : '$unread sin leer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$total avisos recientes · historial compartido con la web',
                  style: const TextStyle(
                    color: Color(0xFFCEC7E8),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final InboxNotification item;
  final VoidCallback onTap;

  IconData get _icon => switch (item.category.toLowerCase()) {
    'meet' => Icons.video_call_rounded,
    'visit' || 'visita' => Icons.location_on_rounded,
    'folio' => Icons.description_rounded,
    'ticket' => Icons.confirmation_number_rounded,
    _ => Icons.notifications_rounded,
  };

  Color get _color => switch (item.category.toLowerCase()) {
    'meet' => const Color(0xFF2563EB),
    'visit' || 'visita' => const Color(0xFF0F766E),
    'folio' => const Color(0xFFB45309),
    'ticket' => MRSTheme.primary,
    _ => const Color(0xFF475569),
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.read ? Colors.white : const Color(0xFFF7F5FF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  item.read ? const Color(0x140F172A) : const Color(0x33200F4C),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: _color, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              color: MRSTheme.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 5),
                            decoration: const BoxDecoration(
                              color: MRSTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      style: const TextStyle(
                        color: MRSTheme.muted,
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _relativeTime(item.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime? value) {
    if (value == null) return '';
    final elapsed = DateTime.now().difference(value);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Ahora';
    if (elapsed.inMinutes < 60) return 'Hace ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'Hace ${elapsed.inHours} h';
    if (elapsed.inDays < 7) return 'Hace ${elapsed.inDays} días';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 54,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 12),
            Text(
              'Todo al día',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 5),
            Text(
              'Los próximos avisos aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MRSTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: MRSTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
