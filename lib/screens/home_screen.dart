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
import 'package:mrsos/services/session_store.dart';
import '../services/app_http.dart';
import '../services/index_service.dart';
import '../widget/mr_skeleton.dart';

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
  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);

  int _tabIndex = 0;

  // ✅ Tabs (NO Navigator.push)
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();

    _tabs = [
      HomeTab(usId: widget.usId, userName: widget.userName),
      // ✅ MIS EQUIPOS (2do botón)
      const MisEquiposTab(),
      // placeholders (los cambiamos después)
      const ReportesTab(),
      const UsuariosTab(),
    ];
  }

  void _openFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18, left: 14, right: 14),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Ticket Servicio'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => CreateTicketScreen(
                                  baseUrl:
                                      'https://yellow-chicken-910471.hostingersite.com/php',
                                ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.health_and_safety_outlined),
                      title: const Text('Health Check'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => HealthCheckScreen(
                                  baseUrl:
                                      'https://yellow-chicken-910471.hostingersite.com/php',
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onTab(int i) => setState(() => _tabIndex = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ Body cambia por tab (sin navegar)
      body: IndexedStack(index: _tabIndex, children: _tabs),

      floatingActionButton: FloatingActionButton(
        onPressed: _openFabMenu,
        backgroundColor: mrPurple,
        foregroundColor: Colors.white,
        elevation: 8,
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: _BottomBar(activeIndex: _tabIndex, onTap: _onTab),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.activeIndex, required this.onTap});

  final int activeIndex;
  final ValueChanged<int> onTap;

  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);

  Widget _btn({required int index, required IconData icon}) {
    final active = activeIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Icon(
          icon,
          size: 26,
          color: active ? mrPurple : const Color(0xFFB8B6C6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 74,
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _btn(index: 0, icon: Icons.home_rounded),
            // ✅ 2do botón = Mis Equipos (cambia icono como pediste)
            _btn(index: 1, icon: Icons.computer_rounded),
            const SizedBox(width: 44),
            _btn(index: 2, icon: Icons.description_rounded),
            _btn(index: 3, icon: Icons.group_rounded),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.usId, required this.userName});

  final String usId;
  final String userName;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const Color cardPurple = Color.fromARGB(255, 8, 4, 247);

  late final IndexService api;

  String _avatarUrl = '';

  Future<void> _loadProfile() async {
    try {
      final u = await SessionStore().getProfile();

      // Basado en otras pantallas: si usImagen == '1' => usar username, si no => avatar_default
      String avatar = (u['usUsername'] ?? '').toString();
      final flag = (u['usImagen'] ?? '').toString();

      if (flag == '1') {
        avatar = (u['usUsername'] ?? '').toString();
      } else {
        avatar = 'avatar_default';
      }

      if (avatar.isEmpty) avatar = 'avatar_default';

      final avatarUrl =
          'https://yellow-chicken-910471.hostingersite.com/img/Usuario/$avatar.jpg';
      if (!mounted) return;
      setState(() => _avatarUrl = avatarUrl);

      // debug
      // ignore: avoid_print
      print(avatarUrl);
    } catch (_) {
      // si falla, dejamos el avatar por default
    }
  }

  bool _loading = true;
  // ignore: unused_field
  bool _refreshing = false;

  Map<String, dynamic> indexData = {};
  Map<String, dynamic> stats = {};
  Map<String, dynamic> ticketsSedes = {};

  @override
  void initState() {
    super.initState();
    api = IndexService(dio: AppHttp.I.dio); // misma cookie PHPSESSID
    _loadAll();
    _loadProfile();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final a = await api.getIndexData(); // getIndexData.php (sesión)
      final b = await api.estadisticasMes(); // estadisticas_mes.php (sesión)
      final c =
          await api.obtenerTicketsSedes(); // obtener_tickets_sedes.php (sesión)

      if (!mounted) return;
      setState(() {
        indexData = a;
        stats = b;
        ticketsSedes = c;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    try {
      await _loadAll();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('no autenticado')) {
        await SessionStore.clear();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeLoginScreen()),
        );
        return;
      }
      // otros errores...
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progresoItems =
        _loading ? <Map<String, dynamic>>[] : _ticketsEnProgreso(indexData);
    final int healthCount =
        _loading ? 0 : _safeInt(indexData['healthChecksCount'] ?? 0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: false,
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          edgeOffset: 12,
          displacement: 18,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              _TopHeader(
                name: widget.userName,
                loading: _loading,
                avatarUrl: _avatarUrl,
              ),
              const SizedBox(height: 14),

              MRSkeleton(
                enabled: _loading,
                child: _MainCard(
                  progress: _loading ? 0.0 : _safeProgressFromRatio(stats),
                  onTickets: () {
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
                  },
                  ticketsAbiertos:
                      _loading ? null : _safeInt(indexData['ticketsAbiertos']),
                  poliza: _loading ? null : (indexData['poliza']?.toString()),
                ),
              ),
              const SizedBox(height: 30),

              if (_loading) ...[
                SizedBox(
                  height: 96,
                  child: MRSkeleton(
                    enabled: _loading,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _loading
                              ? 2
                              : _safeList(indexData, 'healthChecks').length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        if (_loading) {
                          return const _HealthCheckMiniCardSkeleton();
                        }

                        final hc =
                            _safeList(indexData, 'healthChecks')[i]
                                as Map<String, dynamic>;
                        return _HealthCheckMiniCard(
                          sede: '${hc['csNombre'] ?? 'Sede'}',
                          fechaHora: '${hc['hcFechaHora'] ?? ''}',
                          equipos: _toInt(hc['equiposCount'] ?? 0),
                          duracionMins: _toInt(hc['hcDuracionMins'] ?? 0),
                          onTap: () {
                            // luego lo conectamos al detalle del HC
                          },
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],
              if (healthCount > 0) ...[
                Row(
                  children: [
                    const Text(
                      'Health Check',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 230, 232, 255),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _loading
                            ? '•'
                            : '${_safeInt(indexData['healthChecksCount'] ?? 0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: cardPurple,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 96,
                  child: MRSkeleton(
                    enabled: _loading,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _loading
                              ? 2
                              : _safeList(indexData, 'healthChecks').length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        if (_loading) {
                          return const _HealthCheckMiniCardSkeleton();
                        }

                        final hc =
                            _safeList(indexData, 'healthChecks')[i]
                                as Map<String, dynamic>;
                        return _HealthCheckMiniCard(
                          sede: '${hc['csNombre'] ?? 'Sede'}',
                          fechaHora: '${hc['hcFechaHora'] ?? ''}',
                          equipos: _toInt(hc['equiposCount'] ?? 0),
                          duracionMins: _toInt(hc['hcDuracionMins'] ?? 0),
                          onTap: () {
                            print('abrir HC ${_toInt(hc['hcId'])}');
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => HealthCheckDetailScreen(
                                      baseUrl:
                                          'https://yellow-chicken-910471.hostingersite.com/php',
                                      hcId: _toInt(hc['hcId']),
                                      hcFolio:
                                          'HC - INE - ${_toInt(hc['hcId'])}', // o si tú guardas INE-12 real, pásalo
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],

              // En progreso (ahora desde getIndexData.php -> "tickets")
              Row(
                children: [
                  const Text(
                    'En Progreso',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 230, 232, 255),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _loading ? '•' : '${progresoItems.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: cardPurple,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_loading)
                    TextButton(
                      onPressed: () {
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
                      },
                      child: const Text(
                        'Ver todo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cardPurple,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 128,
                child: MRSkeleton(
                  enabled: _loading,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        _loading
                            ? 2
                            : (progresoItems.isEmpty
                                ? 1
                                : progresoItems.length),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      if (_loading) return const _ProgressMiniCardSkeleton();

                      if (progresoItems.isEmpty) {
                        return const _EmptyMiniCard();
                      }

                      final item = progresoItems[i];
                      final tiId = item['folio']?.toString() ?? '--';
                      final tiIdNum = _safeInt(item['tiId']);
                      final desc = (item['peSN'] ?? '').toString();
                      final crit = (item['tiNivelCriticidad'] ?? '').toString();
                      final proc = (item['tiProceso'] ?? '').toString();

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => TicketDetailScreen(
                                    tiId: tiIdNum,
                                    folio:
                                        '${item['folio'] ?? 'TI - ${item['tiId']}'}',
                                  ),
                            ),
                          );
                        },
                        child: _ProgressMiniCard(
                          folio: tiId,
                          status: crit.isEmpty ? 'En proceso' : proc,
                          sn: desc.isEmpty ? 'Sin descripción' : desc,
                          percent: _fakePercentByCrit(crit),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Grupos / Sedes (ahora usa csNombre y tickets.length)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Grupos/Sedes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!_loading)
                    TextButton(
                      onPressed: () {
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
                      },
                      child: const Text(
                        'Ver todo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cardPurple,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              MRSkeleton(
                enabled: _loading,
                child: Column(
                  children: List.generate(
                    _loading ? 3 : _safeList(ticketsSedes, 'sedes').length,
                    (i) {
                      if (_loading) return const _SedeRowSkeleton();

                      final sede =
                          _safeList(ticketsSedes, 'sedes')[i]
                              as Map<String, dynamic>;
                      final csNombre = (sede['csNombre'] ?? 'Sede').toString();
                      final tickets =
                          (sede['tickets'] is List)
                              ? (sede['tickets'] as List)
                              : const [];
                      final count = tickets.length;

                      final csId = _safeInt(sede['csId']);

                      return _SedeRow(
                        onTap: () {
                          final csId = _safeInt(sede['csId']);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => TicketsSedesScreen(
                                    usId: widget.usId,
                                    userName: widget.userName,
                                    initialCsId: csId == 0 ? null : csId,
                                  ),
                            ),
                          );
                        },
                        title: csNombre,
                        subtitle: '$count Tickets',
                        iconBg:
                            i % 2 == 0
                                ? const Color(0xFFFFE6F2)
                                : const Color.fromARGB(255, 230, 232, 255),
                        icon:
                            i % 2 == 0
                                ? Icons.inventory_2_outlined
                                : Icons.apartment_rounded,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- helpers de data ----------
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

  // getIndexData.php devuelve: tickets[] con tiId, tiDescripcion, tiFechaCreacion, tiNivelCriticidad
  List<Map<String, dynamic>> _ticketsEnProgreso(Map<String, dynamic> index) {
    final raw = index['tickets'];
    if (raw is! List) return [];
    final items =
        raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

    // Si quieres: filtra por criticidad o por fecha
    // por ahora: top 6 recientes
    return items.take(6).toList();
  }

  // estadisticas_mes.php devuelve ratio: {finalizados,total}
  double _safeProgressFromRatio(Map<String, dynamic> s) {
    final ratio = s['ratio'];
    if (ratio is Map) {
      final r = Map<String, dynamic>.from(ratio);
      final fin = _safeInt(r['finalizados']);
      final tot = _safeInt(r['total']);

      if (tot <= 0) return -1.0; // sin datos
      return (fin / tot).clamp(0.0, 1.0);
    }
    return -1.0; // sin datos
  }

  // Solo para que se vea bonito el avance en mini-cards (hasta que definamos un campo real de avance)
  double _fakePercentByCrit(String crit) {
    final c = crit.toLowerCase();
    if (c.contains('1')) return 1.0;
    if (c.contains('2')) return 0.5;
    if (c.contains('3')) return 0.35;
    return 0.80;
  }
}

// ---------------- UI widgets ----------------

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.name, required this.loading, this.avatarUrl});
  final String name;
  final bool loading;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (avatarUrl ?? '').isNotEmpty;
    final img = (!loading && hasAvatar) ? NetworkImage(avatarUrl!) : null;
    return Row(
      children: [
        MRSkeleton(
          enabled: loading,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color.fromARGB(255, 230, 232, 255),
            backgroundImage: img,
            onBackgroundImageError: img == null ? null : (_, __) {},
            child:
                loading
                    ? const SizedBox.shrink()
                    : (hasAvatar
                        ? const SizedBox.shrink()
                        : const Icon(
                          Icons.person_rounded,
                          color: Color.fromARGB(255, 40, 22, 100),
                        )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¡Hola',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B667A),
                ),
              ),
              MRSkeleton(
                enabled: loading,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => UserProfileScreen(
                              baseUrl:
                                  'https://yellow-chicken-910471.hostingersite.com/php',
                            ),
                      ),
                    );
                  },
                  child: Text(
                    name.isEmpty ? 'Usuario!' : "$name!",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _MainCard extends StatelessWidget {
  const _MainCard({
    required this.progress,
    required this.onTickets,
    this.ticketsAbiertos,
    this.poliza,
  });

  final double progress;
  final VoidCallback onTickets;
  final int? ticketsAbiertos;
  final String? poliza;

  static const Color cardPurple = Color.fromARGB(255, 40, 22, 100);

  @override
  Widget build(BuildContext context) {
    final bool hasData = progress >= 0.0 && progress <= 1.0;
    final double? progressValue = hasData ? progress : null;

    final subt =
        (ticketsAbiertos == null || poliza == null)
            ? 'Cargando…'
            : 'Póliza: $poliza • Abiertos: $ticketsAbiertos';

    return Container(
      height: 128,
      decoration: BoxDecoration(
        color: cardPurple,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF11B5FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: cardPurple.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tus tickets al día',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: onTickets,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: cardPurple,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Ver Tickets',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressValue, // null => animado
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Text(
                  hasData ? '${(progress * 100).round()}%' : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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

class _EmptyMiniCard extends StatelessWidget {
  const _EmptyMiniCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          'Sin tickets\npor ahora',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF6B667A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProgressMiniCard extends StatelessWidget {
  const _ProgressMiniCard({
    required this.folio,
    required this.status,
    required this.sn,
    required this.percent,
  });

  final String folio;
  final String status;
  final String sn;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                folio,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B667A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 230, 232, 255),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: Color.fromARGB(255, 40, 20, 105),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(status, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            sn,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF6B667A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: const Color(0xFFE3E7FF),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 1.0
                    ? const Color.fromARGB(255, 200, 51, 40)
                    : percent == 0.5
                    ? const Color.fromARGB(255, 250, 180, 40)
                    : const Color.fromARGB(255, 50, 220, 78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMiniCardSkeleton extends StatelessWidget {
  const _ProgressMiniCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 12, width: 110),
          SizedBox(height: 10),
          SkeletonBox(height: 16, width: 120),
          SizedBox(height: 10),
          SkeletonBox(height: 12, width: 160),
          Spacer(),
          SkeletonBox(height: 8, width: 170, radius: 99),
        ],
      ),
    );
  }
}

class _SedeRow extends StatelessWidget {
  const _SedeRow({
    this.onTap,
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.icon,
  });

  final VoidCallback? onTap;
  final String title;
  final String subtitle;
  final Color iconBg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color.fromARGB(255, 40, 22, 100)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B667A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SedeRowSkeleton extends StatelessWidget {
  const _SedeRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          SkeletonBox(height: 38, width: 38, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 220),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _toInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

class _HealthCheckMiniCard extends StatelessWidget {
  const _HealthCheckMiniCard({
    required this.sede,
    required this.fechaHora,
    required this.equipos,
    required this.duracionMins,
    required this.onTap,
  });

  final String sede;
  final String fechaHora;
  final int equipos;
  final int duracionMins;
  final VoidCallback onTap;

  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);

  String _pretty(String s) {
    // llega "2025-12-04 09:30:00"
    if (s.length < 16) return s;
    return '${s.substring(0, 10)}  ${s.substring(11, 16)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 230, 232, 255),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: mrPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sede,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _pretty(fechaHora),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B667A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$equipos equipos • ${duracionMins ~/ 60}h',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthCheckMiniCardSkeleton extends StatelessWidget {
  const _HealthCheckMiniCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          SkeletonBox(height: 38, width: 38, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 160),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 110),
                Spacer(),
                SkeletonBox(height: 12, width: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MrBottomNav extends StatelessWidget {
  const MrBottomNav({super.key, required this.activeIndex, this.onTap});
  final int activeIndex;
  final void Function(int index)? onTap;

  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom; // gestos
    final safeBottom = inset > 0 ? inset : 0.0;

    // Fondo lila de ancho completo para que NO se vean “bordes” laterales
    return SizedBox(
      height: 66 + safeBottom,
      child: Stack(
        children: [
          // ✅ Fondo completo (evita el “hueco” blanco a los lados)
          Positioned.fill(
            child: Container(
              alignment: Alignment.bottomCenter,
              decoration: const BoxDecoration(color: Color(0xFFEFEAFF)),
            ),
          ),

          // ✅ Pill centrada, con margen lateral como tu diseño
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              elevation: 18,
              shadowColor: Colors.black.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEAFF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BottomAppBar(
                    color: Colors.transparent,
                    elevation: 0,
                    shape: const CircularNotchedRectangle(),
                    notchMargin: 10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MrNavIcon(
                            icon: Icons.home_rounded,
                            active: activeIndex == 0,
                            onPressed: () => onTap?.call(0),
                          ),
                          _MrNavIcon(
                            icon: Icons.calendar_month_rounded,
                            active: activeIndex == 1,
                            onPressed: () => onTap?.call(1),
                          ),
                          const SizedBox(width: 54),
                          _MrNavIcon(
                            icon: Icons.description_rounded,
                            active: activeIndex == 2,
                            onPressed: () => onTap?.call(2),
                          ),
                          _MrNavIcon(
                            icon: Icons.group_rounded,
                            active: activeIndex == 3,
                            onPressed: () => onTap?.call(3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MrNavIcon extends StatelessWidget {
  const _MrNavIcon({required this.icon, required this.active, this.onPressed});

  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;

  static const Color mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active ? mrPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              active
                  ? [
                    BoxShadow(
                      color: mrPurple.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        child: Icon(
          icon,
          size: 26,
          color: active ? Colors.white : const Color(0xFFB8B6C6),
        ),
      ),
    );
  }
}
