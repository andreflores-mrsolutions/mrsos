import 'package:flutter/material.dart';
import 'visita_asignar_screen.dart';
import 'visita_proponer_screen.dart';
import 'visita_modificar_screen.dart';
import 'visita_datos_screen.dart';
import '../services/visita_service.dart';

enum VisitaAccionesModo { crear, gestionar }

class VisitaAccionesSheet extends StatelessWidget {
  const VisitaAccionesSheet({
    super.key,
    required this.tiId,
    required this.ticket,
    required this.modo,
  });

  final int tiId;
  final Map<String, dynamic> ticket;
  final VisitaAccionesModo modo;

  static const purple = Color(0xFF4F46E5);
  static const danger = Color(0xFFFF6B6B);

  String _s(dynamic v) => (v ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final estado = _s(ticket['tiVisitaEstado']).toLowerCase().trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            modo == VisitaAccionesModo.crear
                ? 'Crear Visita'
                : 'Gestionar Visita',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),

          // ✅ MODO CREAR: solo asignar / proponer
          if (modo == VisitaAccionesModo.crear) ...[
            _btn(
              context,
              icon: Icons.event_available_rounded,
              title: 'Asignar visita',
              color: purple,
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => VisitaAsignarScreen(tiId: tiId, ticket: ticket),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _btn(
              context,
              icon: Icons.event_note_rounded,
              title: 'Proponer visita',
              color: purple,
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => VisitaProponerScreen(tiId: tiId, ticket: ticket),
                  ),
                );
              },
            ),
          ],

          // ✅ MODO GESTIONAR: ver / modificar / cancelar
          if (modo == VisitaAccionesModo.gestionar) ...[
            _btn(
              context,
              icon: Icons.visibility_rounded,
              title: 'Ver detalles',
              color: purple,
              onTap: () async {
                Navigator.pop(context);
                // Si ya requiere folio, mandamos directo a datos
                if (estado == 'requiere_folio') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => VisitaDatosScreen(tiId: tiId, ticket: ticket),
                    ),
                  );
                  return;
                }

                // Si no requiere folio, mostramos la pantalla de modificar como "detalle editable"
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                            VisitaModificarScreen(tiId: tiId, ticket: ticket),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _btn(
              context,
              icon: Icons.edit_calendar_rounded,
              title: 'Modificar visita',
              color: purple,
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                            VisitaModificarScreen(tiId: tiId, ticket: ticket),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _btn(
              context,
              icon: Icons.delete_forever_rounded,
              title: 'Cancelar visita',
              color: danger,
              onTap: () async {
                Navigator.pop(context);
                final ok = await _confirmCancel(context);
                if (ok != true) return;

                try {
                  await VisitaService.I.cancelar(
                    tiId: tiId,
                    motivo: 'Cancelado por cliente',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Visita cancelada')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _btn(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bg = color.withOpacity(.12);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmCancel(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Cancelar visita'),
            content: const Text('¿Seguro que deseas cancelar la visita?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sí, cancelar'),
              ),
            ],
          ),
    );
  }
}
