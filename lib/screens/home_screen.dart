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
import 'package:mrsos/services/push_router.dart';
import 'package:mrsos/services/session_store.dart';
import '../services/app_http.dart';
import '../services/index_service.dart';
import '../widget/mr_skeleton.dart';

class MRSColors {
  static const Color primary = Color(0xFF200F4C);
  static const Color primaryDark = Color(0xFF160A38);
  static const Color accent = Color(0xFF1F6FFF);
  static const Color bg = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color soft = Color(0xFFF6F7FB);
  static const Color border = Color(0x140F172A);
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF166534);
  static const Color warningBg = Color(0xFFFFF7ED);
  static const Color warningText = Color(0xFFC2410C);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color infoText = Color(0xFF1D4ED8);
}

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
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    PushRouter.openIfAny();

    _tabs = [
      HomeTab(usId: widget.usId, userName: widget.userName),
      const MisEquiposTab(),
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.add_circle_outline,
                        color: MRSColors.primary,
                      ),
                      title: const Text('Ticket Servicio'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => CreateTicketScreen(
                                  baseUrl: 'https://mrsos.com.mx/php',
                                ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.health_and_safety_outlined,
                        color: MRSColors.primary,
                      ),
                      title: const Text('Health Check'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => HealthCheckScreen(
                                  baseUrl: 'https://mrsos.com.mx/php',
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
      backgroundColor: MRSColors.bg,
      body: IndexedStack(index: _tabIndex, children: _tabs),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFabMenu,
        backgroundColor: MRSColors.primary,
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
          color: active ? MRSColors.primary : const Color(0xFF94A3B8),
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
      shadowColor: const Color(0x120F172A),
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _btn(index: 0, icon: Icons.home_rounded),
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

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.usId, required this.userName});

  final String usId;
  final String userName;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final IndexService api;

  String _avatarUrl = '';
  bool _loading = true;
  bool _refreshing = false;

  Map<String, dynamic> indexData = {};
  Map<String, dynamic> stats = {};
  Map<String, dynamic> ticketsSedes = {};

  @override
  void initState() {
    super.initState();
    api = IndexService(dio: AppHttp.I.dio);
    _loadAll();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final u = await SessionStore().getProfile();
      String avatar = (u['usUsername'] ?? '').toString();
      final flag = (u['usImagen'] ?? '').toString();

      if (flag != '1') {
        avatar = 'avatar_default';
      }
      if (avatar.isEmpty) avatar = 'avatar_default';

      final avatarUrl = 'https://mrsos.com.mx/img/Usuario/$avatar.jpg';
      if (!mounted) return;
      setState(() => _avatarUrl = avatarUrl);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final a = await api.getIndexData();
      final b = await api.estadisticasMes();
      final c = await api.obtenerTicketsSedes();

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
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progresoItems =
        _loading
            ? <Map<String, dynamic>>[]
            : _ticketsEnProgresoEnriquecidos(indexData, ticketsSedes);

    final int healthCount =
        _loading ? 0 : _safeInt(indexData['healthChecksCount'] ?? 0);

    final int totalTickets =
        _loading ? 0 : _safeList(indexData, 'tickets').length;
    final int abiertos =
        _loading ? 0 : _safeInt(indexData['ticketsAbiertos'] ?? totalTickets);
    final int accion = _loading ? 0 : _countActionRequired(progresoItems);
    final int curso = _loading ? 0 : progresoItems.length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: false,
      backgroundColor: MRSColors.bg,
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
              const SizedBox(height: 16),
              MRSkeleton(
                enabled: _loading,
                child: _KpiGrid(
                  total: totalTickets,
                  abiertos: abiertos,
                  accion: accion,
                  curso: curso,
                ),
              ),
              const SizedBox(height: 16),
              MRSkeleton(
                enabled: _loading,
                child: _MainCard(
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
                  poliza: _loading ? null : indexData['poliza']?.toString(),
                  enCurso: curso,
                  miAccion: accion,
                ),
              ),
              const SizedBox(height: 28),
              if (healthCount > 0 || _loading) ...[
                _SectionHeader(
                  title: 'Health Check',
                  count: _loading ? 0 : healthCount,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 142,
                  child: MRSkeleton(
                    enabled: _loading,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _loading
                              ? 2
                              : _safeList(indexData, 'healthChecks').length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, i) {
                        if (_loading) {
                          return const _HealthAgendaCardSkeleton();
                        }
                        final hc =
                            _safeList(indexData, 'healthChecks')[i]
                                as Map<String, dynamic>;
                        return _HealthAgendaCard(
                          sede: '${hc['csNombre'] ?? 'Sede'}',
                          fechaHora: _prettyDateTime(
                            '${hc['hcFechaHora'] ?? ''}',
                          ),
                          equipos: _toInt(hc['equiposCount'] ?? 0),
                          duracionTexto: _durationTextFromMinutes(
                            _toInt(hc['hcDuracionMins'] ?? 0),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => HealthCheckDetailScreen(
                                      baseUrl: 'https://mrsos.com.mx/php',
                                      hcId: _toInt(hc['hcId']),
                                      hcFolio:
                                          'HC - INE - ${_toInt(hc['hcId'])}',
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 22),
              ],
              _SectionHeader(
                title: 'En Progreso',
                count: _loading ? 0 : progresoItems.length,
                onViewAll:
                    _loading
                        ? null
                        : () {
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
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 336,
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
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      if (_loading) return const _TicketHeroCardSkeleton();

                      if (progresoItems.isEmpty) {
                        return Container(
                          width: 292,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: MRSColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'Sin tickets por ahora',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MRSColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }

                      final item = progresoItems[i];
                      final tiIdNum = _safeInt(item['tiId']);
                      final crit = (item['tiNivelCriticidad'] ?? '').toString();

                      return _TicketHeroCard(
                        folio: (item['folio'] ?? '--').toString(),
                        equipo: _ticketEquipmentName(item),
                        marcaVersion: _ticketBrandVersion(item),
                        sn: _ticketSerial(item),
                        sede: _ticketSite(item),
                        pasoActual: _ticketPasoActual(item),
                        progress: _fakePercentByCrit(crit),
                        progressText: _progressTextFromCrit(crit),
                        estado: _ticketEstadoLabel(item),
                        criticidad: _ticketCriticidadLabel(
                          item['tiNivelCriticidad'],
                        ),
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
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Grupos/Sedes',
                count: _loading ? 0 : _safeList(ticketsSedes, 'sedes').length,
                onViewAll:
                    _loading
                        ? null
                        : () {
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
              ),
              const SizedBox(height: 10),
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
                        subtitle: '$count ticket(s)',
                        iconBg: const Color(0xFFEFF6FF),
                        icon: Icons.apartment_rounded,
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

    return items.take(6).toList();
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

  String _ticketEquipmentName(Map<String, dynamic> item) {
    final candidates = [
      item['eqModelo'],
      item['equipo'],
      item['eqNombre'],
      item['peEquipo'],
      item['tiEquipo'],
      item['tiDescripcion'],
      item['descripcion'],
      item['titulo'],
    ];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return 'Equipo registrado';
  }

  String _ticketBrandVersion(Map<String, dynamic> item) {
    final parts =
        [
          (item['maNombre'] ?? '').toString().trim(),
          (item['eqVersion'] ?? '').toString().trim(),
        ].where((e) => e.isNotEmpty).toList();

    if (parts.isEmpty) return 'Activo en seguimiento';
    return parts.join(' ');
  }

  String _ticketSerial(Map<String, dynamic> item) {
    final candidates = [
      item['peSN'],
      item['serialNumber'],
      item['serial'],
      item['sn'],
      item['tiSerial'],
    ];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return 'Sin SN';
  }

  String _ticketSite(Map<String, dynamic> item) {
    final candidates = [item['csNombre'], item['sede'], item['zona']];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return 'Sede principal';
  }

  String _ticketPasoActual(Map<String, dynamic> item) {
    final s = (item['tiProceso'] ?? '').toString().trim();
    return s.isEmpty ? 'Sin proceso' : s;
  }

  String _ticketEstadoLabel(Map<String, dynamic> item) {
    final proc = (item['tiProceso'] ?? '').toString().toLowerCase();
    if (proc.contains('logs') ||
        proc.contains('meet') ||
        proc.contains('visita') ||
        proc.contains('encuesta')) {
      return 'En curso';
    }
    return 'Abierto';
  }

  String _ticketCriticidadLabel(dynamic value) {
    final n = _safeInt(value, fallback: 3);
    return 'Nivel $n';
  }

  String _progressTextFromCrit(String crit) {
    final c = crit.toLowerCase();
    if (c.contains('1')) return 'Alta';
    if (c.contains('2')) return 'Media';
    if (c.contains('3')) return 'Base';
    return 'Activa';
  }

  String _durationTextFromMinutes(int mins) {
    if (mins <= 0) return 'Sin duración';
    if (mins < 60) return '${mins} min';
    final h = mins ~/ 60;
    final r = mins % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  String _prettyDateTime(String s) {
    if (s.length < 16) return s;
    return '${s.substring(0, 10)} · ${s.substring(11, 16)}';
  }

  double _fakePercentByCrit(String crit) {
    final c = crit.toLowerCase();
    if (c.contains('1')) return 1.0;
    if (c.contains('2')) return 0.6;
    if (c.contains('3')) return 0.35;
    return 0.80;
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.name, required this.loading, this.avatarUrl});

  final String name;
  final bool loading;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (avatarUrl ?? '').isNotEmpty;
    final img = (!loading && hasAvatar) ? NetworkImage(avatarUrl!) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MRSColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MRSColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          MRSkeleton(
            enabled: loading,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFEAF0FF),
              backgroundImage: img,
              onBackgroundImageError: img == null ? null : (_, __) {},
              child:
                  hasAvatar
                      ? const SizedBox.shrink()
                      : const Icon(
                        Icons.person_rounded,
                        color: MRSColors.primary,
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MRSkeleton(
              enabled: loading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MRSColors.successText,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Cliente',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MR SOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: MRSColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => UserProfileScreen(
                                baseUrl: 'https://mrsos.com.mx/php',
                              ),
                        ),
                      );
                    },
                    child: Text(
                      name.isEmpty ? 'Hola, Usuario' : 'Hola, $name',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MRSColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Mis tickets y acciones pendientes',
                    style: TextStyle(
                      fontSize: 13,
                      color: MRSColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: MRSColors.soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MRSColors.border),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: MRSColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.total,
    required this.abiertos,
    required this.accion,
    required this.curso,
  });

  final int total;
  final int abiertos;
  final int accion;
  final int curso;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.75,
      children: [
        _KpiCard(label: 'Total', value: total),
        _KpiCard(label: 'Abiertos', value: abiertos),
        _KpiCard(label: 'Requieren mi acción', value: accion),
        _KpiCard(label: 'En curso', value: curso),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MRSColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MRSColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: MRSColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: MRSColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  const _MainCard({
    required this.onTickets,
    this.ticketsAbiertos,
    this.poliza,
    required this.enCurso,
    required this.miAccion,
  });

  final VoidCallback onTickets;
  final int? ticketsAbiertos;
  final String? poliza;
  final int enCurso;
  final int miAccion;

  @override
  Widget build(BuildContext context) {
    final subt =
        (ticketsAbiertos == null || poliza == null)
            ? 'Cargando información del servicio...'
            : 'Póliza $poliza · $ticketsAbiertos ticket(s) abiertos';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MRSColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MRSColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de servicio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: MRSColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subt,
            style: const TextStyle(
              fontSize: 13,
              color: MRSColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: onTickets,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text(
                      'Ver tickets',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MRSColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MRSColors.soft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MRSColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MiniMetric(
                      label: 'En curso',
                      value: '$enCurso',
                      valueColor: MRSColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _MiniMetric(
                      label: 'Mi acción',
                      value: '$miAccion',
                      valueColor: MRSColors.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: MRSColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.onViewAll,
  });

  final String title;
  final int count;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: MRSColors.text,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MRSColors.infoBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: MRSColors.infoText,
            ),
          ),
        ),
        const Spacer(),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text(
              'Ver todo',
              style: TextStyle(
                color: MRSColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _SoftInfoChip extends StatelessWidget {
  const _SoftInfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MRSColors.muted),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: MRSColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketHeroCard extends StatelessWidget {
  const _TicketHeroCard({
    required this.folio,
    required this.equipo,
    required this.marcaVersion,
    required this.sn,
    required this.sede,
    required this.pasoActual,
    required this.progress,
    required this.progressText,
    required this.estado,
    required this.criticidad,
    this.onTap,
  });

  final String folio;
  final String equipo;
  final String marcaVersion;
  final String sn;
  final String sede;
  final String pasoActual;
  final double progress;
  final String progressText;
  final String estado;
  final String criticidad;
  final VoidCallback? onTap;

  Color _estadoBg() {
    switch (estado.toLowerCase()) {
      case 'abierto':
        return MRSColors.successBg;
      case 'en curso':
        return MRSColors.infoBg;
      case 'pospuesto':
        return MRSColors.warningBg;
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _estadoText() {
    switch (estado.toLowerCase()) {
      case 'abierto':
        return MRSColors.successText;
      case 'en curso':
        return MRSColors.accent;
      case 'pospuesto':
        return MRSColors.warningText;
      default:
        return MRSColors.muted;
    }
  }

  Color _criticidadBg() {
    switch (criticidad.toLowerCase()) {
      case 'nivel 1':
        return MRSColors.dangerBg;
      case 'nivel 2':
        return MRSColors.warningBg;
      case 'nivel 3':
        return const Color(0xFFF1F5F9);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _criticidadText() {
    switch (criticidad.toLowerCase()) {
      case 'nivel 1':
        return MRSColors.dangerText;
      case 'nivel 2':
        return MRSColors.warningText;
      case 'nivel 3':
        return const Color(0xFF475569);
      default:
        return MRSColors.muted;
    }
  }

  Color _progressColor() {
    if (progress >= 0.9) return const Color(0xFFDC2626);
    if (progress >= 0.6) return const Color(0xFFF59E0B);
    return MRSColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: MRSColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    folio,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: MRSColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                _SoftBadge(text: estado, bg: _estadoBg(), fg: _estadoText()),
                const SizedBox(width: 8),
                _SoftBadge(
                  text: criticidad,
                  bg: _criticidadBg(),
                  fg: _criticidadText(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              equipo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: MRSColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$marcaVersion · SN: $sn',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: MRSColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sede,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: MRSColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paso actual',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: MRSColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    pasoActual,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: MRSColors.text,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE8EDF5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progressColor(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  progressText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: MRSColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: MRSColors.accent,
                ),
                SizedBox(width: 6),
                Text(
                  'Ver detalle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: MRSColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketHeroCardSkeleton extends StatelessWidget {
  const _TicketHeroCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: MRSColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(height: 14, width: 70),
              Spacer(),
              SkeletonBox(height: 24, width: 64, radius: 999),
              SizedBox(width: 8),
              SkeletonBox(height: 24, width: 54, radius: 999),
            ],
          ),
          SizedBox(height: 18),
          SkeletonBox(height: 22, width: 180),
          SizedBox(height: 8),
          SkeletonBox(height: 12, width: 210),
          SizedBox(height: 4),
          SkeletonBox(height: 12, width: 120),
          SizedBox(height: 18),
          SkeletonBox(height: 64, width: 260, radius: 18),
          Spacer(),
          SkeletonBox(height: 8, width: 260, radius: 999),
          SizedBox(height: 14),
          SkeletonBox(height: 14, width: 90),
        ],
      ),
    );
  }
}

class _HealthAgendaCard extends StatelessWidget {
  const _HealthAgendaCard({
    required this.sede,
    required this.fechaHora,
    required this.equipos,
    required this.duracionTexto,
    this.onTap,
  });

  final String sede;
  final String fechaHora;
  final int equipos;
  final String duracionTexto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MRSColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: MRSColors.infoBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: MRSColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sede,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: MRSColors.text,
                          ),
                        ),
                      ),
                      const _SoftBadge(
                        text: 'Programado',
                        bg: Color(0xFFECFDF3),
                        fg: Color(0xFF15803D),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fechaHora,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MRSColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SoftInfoChip(
                        icon: Icons.inventory_2_outlined,
                        text: '$equipos equipos',
                      ),
                      _SoftInfoChip(
                        icon: Icons.schedule_rounded,
                        text: duracionTexto,
                      ),
                    ],
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

class _HealthAgendaCardSkeleton extends StatelessWidget {
  const _HealthAgendaCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MRSColors.border),
      ),
      child: const Row(
        children: [
          SkeletonBox(height: 58, width: 58, radius: 18),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 16, width: 150),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 120),
                SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonBox(height: 28, width: 88, radius: 999),
                    SizedBox(width: 8),
                    SkeletonBox(height: 28, width: 72, radius: 999),
                  ],
                ),
              ],
            ),
          ),
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MRSColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MRSColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: MRSColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: MRSColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MRSColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: MRSColors.muted),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MRSColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MRSColors.border),
      ),
      child: const Row(
        children: [
          SkeletonBox(height: 46, width: 46, radius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 180),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 100),
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
