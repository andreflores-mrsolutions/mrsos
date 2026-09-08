import 'package:flutter/material.dart';
import 'package:mrsos/screens/createhealth_screen.dart';
import 'package:mrsos/screens/createticket_screen.dart';
import 'package:mrsos/screens/equipos/mis_equipos_screen.dart';
import 'package:mrsos/screens/health_check_detail_screen.dart';
import 'package:mrsos/screens/login_screen.dart';
import 'package:mrsos/screens/reportes_tab.dart';
import 'package:mrsos/screens/ticket_detail_screen.dart';
import 'package:mrsos/screens/tickets_sedes_screen.dart';
import 'package:mrsos/screens/user_profile_screen.dart';
import 'package:mrsos/screens/usuarios_list_screen.dart';
import '../services/push_service.dart';
import '../screens/notifications_screen.dart';
import '../config/app_config.dart';
import 'package:mrsos/services/session_store.dart';
import '../services/app_http.dart';
import '../services/index_service.dart';
import '../widget/colors.dart';
import '../widget/home_overview.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.usId,
    required this.userName,
  });
  final String usId;
  final String userName;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _tabIndex = 0;
  final Map<int, Widget> _visitedTabs = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PushService.I.signedIn();
    });
  }

  @override
  void dispose() {
    PushService.I.lock();
    super.dispose();
  }

  Widget _page(int index) => _visitedTabs.putIfAbsent(
    index,
    () => switch (index) {
      0 => HomeTab(
        usId: widget.usId,
        userName: widget.userName,
        onTickets: () => setState(() => _tabIndex = 1),
      ),
      1 => TicketsSedesScreen(
        usId: widget.usId,
        userName: widget.userName,
        embedded: true,
      ),
      2 => const MisEquiposTab(),
      3 => const ReportesTab(),
      _ => const UsuariosTab(),
    },
  );

  @override
  Widget build(BuildContext context) {
    _page(_tabIndex);
    return Scaffold(
      backgroundColor: MRSColors.bg,
      body: IndexedStack(
        index: _tabIndex,
        children: List.generate(
          5,
          (i) => _visitedTabs[i] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: MRSColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number_rounded),
              label: 'Tickets',
            ),
            NavigationDestination(
              icon: Icon(Icons.dns_outlined),
              selectedIcon: Icon(Icons.dns_rounded),
              label: 'Equipos',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description_rounded),
              label: 'Archivos',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Personas',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.usId,
    required this.userName,
    this.onTickets,
  });

  final VoidCallback? onTickets;

  final String usId;
  final String userName;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final IndexService api;

  String _avatarUrl = '';
  bool _loading = true;
  String? _error;

  Map<String, dynamic> indexData = {};
  Map<String, dynamic> stats = {};
  Map<String, dynamic> ticketsSedes = {};

  @override
  void initState() {
    super.initState();
    api = IndexService(dio: AppHttp.I.dio);
    _onRefresh();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final u = await SessionStore().getProfile();
      final avatarUrl = AppConfig.avatarUrl(
        u['usImagen'],
        username: '${u['usUsername'] ?? ''}',
      );
      if (!mounted) return;
      setState(() => _avatarUrl = avatarUrl);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final current = await api.tickets();
      final meta = AppHttp.jsonMap(current['meta'] ?? {});
      Map<String, dynamic> supplemental = {};
      String? warning;
      try {
        supplemental = await api.getIndexData();
      } catch (_) {
        warning =
            'Tickets actualizados. No se pudo consultar la agenda de Health Check.';
      }
      if (!mounted) return;
      setState(() {
        indexData = {
          ...supplemental,
          'tickets': current['tickets'],
          'ticketsAbiertos': meta['abiertos'],
          'actionCount': meta['accion'],
        };
        stats = meta;
        ticketsSedes = IndexService.groupBySite(current);
        _error = warning;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    try {
      await _loadAll();
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppHttp.friendlyError(e));
      }
      final msg = e.toString().toLowerCase();
      if (msg.contains('no autenticado')) {
        await SessionStore.clear();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeLoginScreen()),
        );
        return;
      }
    }
  }

  Future<void> _onNotificationPressed() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openTickets() {
    if (widget.onTickets != null) {
      widget.onTickets!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => TicketsSedesScreen(
                usId: widget.usId,
                userName: widget.userName,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        _loading
            ? <Map<String, dynamic>>[]
            : _ticketsEnProgresoEnriquecidos(indexData, ticketsSedes);
    return HomeOverview(
      name: widget.userName,
      avatarUrl: _avatarUrl,
      loading: _loading,
      error: _error,
      openTickets: _safeInt(
        indexData['ticketsAbiertos'] ?? _safeList(indexData, 'tickets').length,
      ),
      actionCount: _safeInt(indexData['actionCount']),
      tickets: items,
      healthChecks:
          _safeList(
            indexData,
            'healthChecks',
          ).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      sites:
          _safeList(
            ticketsSedes,
            'sedes',
          ).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      onRefresh: _onRefresh,
      onTickets: _openTickets,
      onNotifications: _onNotificationPressed,
      onProfile:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => const UserProfileScreen(
                    baseUrl: 'https://mrsos.com.mx/php',
                  ),
            ),
          ),
      onCreateTicket:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) =>
                      CreateTicketScreen(baseUrl: 'https://mrsos.com.mx/php'),
            ),
          ),
      onCreateHealth:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => HealthCheckScreen(baseUrl: 'https://mrsos.com.mx/php'),
            ),
          ),
      onTicket: (item) {
        final id = _safeInt(item['tiId']);
        if (id <= 0) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => TicketDetailScreen(
                  tiId: id,
                  folio: '${item['folio'] ?? 'TI - $id'}',
                ),
          ),
        );
      },
      onHealth:
          (item) => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => HealthCheckDetailScreen(
                    baseUrl: 'https://mrsos.com.mx/php',
                    hcId: _safeInt(item['hcId']),
                    hcFolio: 'HC - ${item['hcId']}',
                  ),
            ),
          ),
      onSite:
          (item) => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => TicketsSedesScreen(
                    usId: widget.usId,
                    userName: widget.userName,
                    initialCsId:
                        _safeInt(item['csId']) == 0
                            ? null
                            : _safeInt(item['csId']),
                  ),
            ),
          ),
    );
  }

  int _safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  List _safeList(Map<String, dynamic> d, String key) {
    final v = d[key];
    if (v is List) return v;
    return [];
  }

  List<Map<String, dynamic>> _ticketsEnProgresoEnriquecidos(
    Map<String, dynamic> index,
    Map<String, dynamic> sedesData,
  ) {
    final raw = index['tickets'];
    if (raw is! List) return [];

    final Map<int, Map<String, dynamic>> extrasById = {};
    final sedes = _safeList(sedesData, 'sedes');
    for (final sede in sedes) {
      if (sede is Map && sede['tickets'] is List) {
        for (final t in sede['tickets']) {
          if (t is Map) {
            final map = Map<String, dynamic>.from(t);
            final id = _safeInt(map['tiId']);
            if (id > 0) extrasById[id] = map;
          }
        }
      }
    }

    final items =
        raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).map((
          item,
        ) {
          final id = _safeInt(item['tiId']);
          final extra = extrasById[id] ?? const <String, dynamic>{};
          return <String, dynamic>{...extra, ...item};
        }).toList();

    return items;
  }

  int _countActionRequired(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final proc = (item['tiProceso'] ?? '').toString().toLowerCase();
      return proc.contains('logs') ||
          proc.contains('meet') ||
          proc.contains('visita') ||
          proc.contains('encuesta');
    }).length;
  }
}
