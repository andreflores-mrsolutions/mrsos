import 'package:flutter/material.dart';

enum SerialMatch { contains, startsWith, endsWith }

List<Map<String, dynamic>> searchEquipment(
  List<Map<String, dynamic>> equipment,
  String query, {
  SerialMatch mode = SerialMatch.contains,
}) {
  final term = query.trim().toLowerCase();
  if (term.isEmpty) return List.of(equipment);
  return equipment.where((e) {
    final sn = '${e['peSN'] ?? e['sn'] ?? ''}'.toLowerCase();
    return switch (mode) {
      SerialMatch.startsWith => sn.startsWith(term),
      SerialMatch.endsWith => sn.endsWith(term),
      SerialMatch.contains => [
        sn,
        e['eqModelo'] ?? e['modelo'],
        e['maNombre'] ?? e['marca'],
      ].join(' ').toLowerCase().contains(term),
    };
  }).toList();
}

Future<Map<String, dynamic>?> pickEquipment(
  BuildContext context,
  List<Map<String, dynamic>> equipment,
) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _EquipmentPicker(equipment: equipment),
);

class _EquipmentPicker extends StatefulWidget {
  const _EquipmentPicker({required this.equipment});
  final List<Map<String, dynamic>> equipment;
  @override
  State<_EquipmentPicker> createState() => _EquipmentPickerState();
}

class _EquipmentPickerState extends State<_EquipmentPicker> {
  String _query = '';
  SerialMatch _mode = SerialMatch.contains;
  @override
  Widget build(BuildContext context) {
    final matches = searchEquipment(widget.equipment, _query, mode: _mode);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Buscar equipo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      labelText: 'Número de serie, modelo o marca',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  DropdownButton<SerialMatch>(
                    value: _mode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: SerialMatch.contains,
                        child: Text('Contiene: SN, modelo o marca'),
                      ),
                      DropdownMenuItem(
                        value: SerialMatch.startsWith,
                        child: Text('El SN empieza con…'),
                      ),
                      DropdownMenuItem(
                        value: SerialMatch.endsWith,
                        child: Text('El SN termina con…'),
                      ),
                    ],
                    onChanged:
                        (v) =>
                            setState(() => _mode = v ?? SerialMatch.contains),
                  ),
                  Text('${matches.length} equipos en esta sede'),
                ],
              ),
            ),
            Expanded(
              child:
                  matches.isEmpty
                      ? const Center(
                        child: Text('No hay coincidencias en esta sede.'),
                      )
                      : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, i) {
                          final equipment = matches[i];
                          return ListTile(
                            title: Text(
                              '${equipment['eqModelo'] ?? equipment['modelo'] ?? 'Equipo'}',
                            ),
                            subtitle: Text(
                              'SN: ${equipment['peSN'] ?? equipment['sn'] ?? 'Sin registrar'}\n'
                              '${equipment['maNombre'] ?? equipment['marca'] ?? ''} · Póliza ${equipment['pcTipoPoliza'] ?? equipment['polizaTipo'] ?? ''}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, equipment),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
