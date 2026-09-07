import 'package:flutter/material.dart';
import 'colors.dart';
import 'mr_components.dart';
import 'mr_theme.dart';
import 'mr_skeleton.dart';

/// Dashboard presentation. Counts and items are supplied by the existing API.
class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.name,
    required this.loading,
    required this.openTickets,
    required this.actionCount,
    required this.tickets,
    required this.healthChecks,
    required this.sites,
    required this.onTickets,
    required this.onCreateTicket,
    required this.onCreateHealth,
    required this.onProfile,
    required this.onNotifications,
    required this.onTicket,
    required this.onHealth,
    required this.onSite,
    required this.onRefresh,
    this.avatarUrl = '',
    this.error,
  });
  final String name;
  final String avatarUrl;
  final bool loading;
  final String? error;
  final int openTickets;
  final int actionCount;
  final List<Map<String, dynamic>> tickets;
  final List<Map<String, dynamic>> healthChecks;
  final List<Map<String, dynamic>> sites;
  final VoidCallback onTickets;
  final VoidCallback onCreateTicket;
  final VoidCallback onCreateHealth;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final ValueChanged<Map<String, dynamic>> onTicket;
  final ValueChanged<Map<String, dynamic>> onHealth;
  final ValueChanged<Map<String, dynamic>> onSite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: MRContentWidth(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            _OverviewHeader(
              name: name,
              avatarUrl: avatarUrl,
              onProfile: onProfile,
              onNotifications: onNotifications,
            ),
            const SizedBox(height: 24),
            _OverviewHero(
              loading: loading,
              openTickets: openTickets,
              actionCount: actionCount,
              onTickets: onTickets,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow =
                    constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final actions = [
                  _QuickAction(
                    title: 'Nuevo ticket',
                    subtitle: 'Solicita soporte',
                    icon: Icons.add_rounded,
                    prominent: true,
                    onTap: onCreateTicket,
                  ),
                  _QuickAction(
                    title: 'Health Check',
                    subtitle: 'Agenda una revisión',
                    icon: Icons.monitor_heart_outlined,
                    onTap: onCreateHealth,
                  ),
                ];
                return narrow
                    ? Column(
                      children: [
                        actions[0],
                        const SizedBox(height: 10),
                        actions[1],
                      ],
                    )
                    : Row(
                      children: [
                        Expanded(child: actions[0]),
                        const SizedBox(width: 12),
                        Expanded(child: actions[1]),
                      ],
                    );
              },
            ),
            const SizedBox(height: 28),
            MRSectionHeading(
              title: 'En seguimiento',
              subtitle: 'Lo que está pasando con tu servicio',
              action: 'Ver todos',
              onAction: onTickets,
            ),
            if (error != null)
              MREmptyState(
                title: 'No pudimos cargar el resumen',
                message: error!,
                icon: Icons.cloud_off_outlined,
                actionLabel: 'Reintentar',
                onAction: onRefresh,
              )
            else if (loading)
              ...List.generate(
                2,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(
                    height: 158,
                    width: double.infinity,
                    radius: 20,
                  ),
                ),
              )
            else if (tickets.isEmpty)
              MREmptyState(
                title: 'Sin tickets en seguimiento',
                message:
                    'Cuando solicites soporte, podrás consultar aquí cada actualización.',
                icon: Icons.task_alt_rounded,
                actionLabel: 'Crear un ticket',
                onAction: onCreateTicket,
              )
            else
              ...tickets
                  .take(3)
                  .map(
                    (ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MROverviewTicket(
                        ticket: ticket,
                        onTap: () => onTicket(ticket),
                      ),
                    ),
                  ),
            if (healthChecks.isNotEmpty) ...[
              const SizedBox(height: 16),
              MRSectionHeading(
                title: 'Próximas revisiones',
                subtitle: 'Tu agenda de mantenimiento',
                action: 'Agendar',
                onAction: onCreateHealth,
              ),
              ...healthChecks.map(
                (item) => _AgendaItem(item: item, onTap: () => onHealth(item)),
              ),
            ],
            if (sites.isNotEmpty) ...[
              const SizedBox(height: 18),
              const MRSectionHeading(
                title: 'Tus sedes',
                subtitle: 'El servicio, en cada ubicación',
              ),
              MRSectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < sites.length; i++) ...[
                      if (i > 0) const Divider(indent: 62),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const MRIconBox(
                          icon: Icons.apartment_rounded,
                          size: 38,
                        ),
                        title: Text(
                          '${sites[i]['csNombre'] ?? 'Sede'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${sites[i]['tickets'] is List ? (sites[i]['tickets'] as List).length : 0} tickets',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 21,
                        ),
                        onTap: () => onSite(sites[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            const Center(
              child: Text(
                'MR SUPPORT ONE SERVICE',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: MRSColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.name,
    required this.avatarUrl,
    required this.onProfile,
    required this.onNotifications,
  });
  final String name;
  final String avatarUrl;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    return Row(
      children: [
        Semantics(
          key: const ValueKey('open-profile'),
          container: true,
          excludeSemantics: true,
          onTap: onProfile,
          button: true,
          label: 'Abrir mi perfil',
          child: InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: MRSColors.blueSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  avatarUrl.isEmpty
                      ? const Icon(
                        Icons.person_outline_rounded,
                        color: MRSColors.accent,
                      )
                      : Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, _, _) => const Icon(
                              Icons.person_outline_rounded,
                              color: MRSColors.accent,
                            ),
                      ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QUÉ GUSTO VERTE',
                style: TextStyle(
                  color: MRSColors.muted,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Hola, ${firstName.isEmpty ? 'bienvenido' : firstName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton.outlined(
          onPressed: onNotifications,
          tooltip: 'Permisos de notificaciones',
          style: IconButton.styleFrom(
            side: const BorderSide(color: MRSColors.border),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.notifications_none_rounded, size: 23),
        ),
      ],
    );
  }
}

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({
    required this.loading,
    required this.openTickets,
    required this.actionCount,
    required this.onTickets,
  });
  final bool loading;
  final int openTickets;
  final int actionCount;
  final VoidCallback onTickets;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [MRSColors.primaryDark, Color(0xFF19366D)],
      ),
    ),
    child: Stack(
      children: [
        const Positioned(
          right: -26,
          top: -22,
          child: ExcludeSemantics(
            child: Icon(
              Icons.blur_circular_rounded,
              size: 190,
              color: Color(0x1227DED0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TU CENTRO DE SERVICIO',
                style: TextStyle(
                  color: Color(0xFF9BB4DA),
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tu operación,\nbajo control.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 23),
              Row(
                children: [
                  Expanded(
                    child: _heroMetric(
                      loading ? '—' : '$openTickets',
                      'Tickets abiertos',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: .15),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _heroMetric(
                      loading ? '—' : '$actionCount',
                      'Requieren acción',
                      color: const Color(0xFF67E3D5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onTickets,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .09),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text('Ir a mis tickets')),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _heroMetric(
    String value,
    String label, {
    Color color = Colors.white,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFC1CEE4),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class MROverviewTicket extends StatelessWidget {
  const MROverviewTicket({
    super.key,
    required this.ticket,
    required this.onTap,
  });
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  String _first(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = (ticket[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final level = int.tryParse('${ticket['tiNivelCriticidad']}');
    final color =
        level == 1
            ? MRSColors.dangerText
            : level == 2
            ? MRSColors.warningText
            : MRSColors.accent;
    final priority =
        level == 1
            ? 'Prioridad alta'
            : level == 2
            ? 'Prioridad media'
            : level == 3
            ? 'Prioridad baja'
            : 'Sin prioridad';
    final process = _first(['tiProceso'], 'En revisión');
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: MRSColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _first(['folio'], 'TI - ${ticket['tiId'] ?? '—'}'),
                    style: const TextStyle(
                      color: MRSColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                  MRStatusPill(label: priority, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _first([
                        'eqModelo',
                        'equipo',
                        'eqNombre',
                        'peEquipo',
                        'tiEquipo',
                        'tiDescripcion',
                        'descripcion',
                        'titulo',
                      ], 'Equipo registrado'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: MRSColors.accent,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                _first(['csNombre', 'sede', 'zona'], 'Sede no indicada'),
                style: const TextStyle(fontSize: 12, color: MRSColors.muted),
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.radio_button_checked_rounded,
                    size: 14,
                    color: MRSColors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      process,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MRSColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaItem extends StatelessWidget {
  const _AgendaItem({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final raw = '${item['hcFechaHora'] ?? ''}';
    final date = DateTime.tryParse(raw);
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: MRSColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: MRSColors.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        date == null ? '—' : '${date.day}',
                        style: const TextStyle(
                          color: MRSColors.accent,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date == null ? 'FECHA' : months[date.month - 1],
                        style: const TextStyle(
                          color: MRSColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['csNombre'] ?? 'Revisión preventiva'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        date == null
                            ? (raw.isEmpty ? 'Fecha por confirmar' : raw)
                            : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} · ${item['equiposCount'] ?? 0} equipos',
                        style: const TextStyle(
                          color: MRSColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MRSColors.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.prominent = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Material(
    color: prominent ? MRSColors.tealSoft : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: prominent ? const Color(0xFFBEE9E1) : MRSColors.border,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: prominent ? MRSColors.tealDark : MRSColors.accent,
                  size: 24,
                ),
                const Spacer(),
                const Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: MRSColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: MRSColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
