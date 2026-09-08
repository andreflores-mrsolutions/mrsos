import '../services/ticket_catalog_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mrsos/services/session_store.dart';
import 'package:mrsos/services/app_http.dart'; // tu singleton dio
import 'package:mrsos/widget/colors.dart';
import 'package:mrsos/widget/mr_theme.dart';
import 'package:mrsos/widget/mr_components.dart';

class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({super.key, required this.baseUrl});
  final String baseUrl; // https://mrsos.com.mx/php

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  final Dio dio = AppHttp.I.dio;

  bool loading = true;
  bool sending = false;

  List<Map<String, dynamic>> equipos = [];
  List<Map<String, dynamic>> sedes = [];

  int? csId;
  final Set<int> selectedEqIds = {};

  DateTime fechaHora = DateTime.now().add(const Duration(days: 1));
  int duracionMins = 240;

  // contacto
  final cNombre = TextEditingController();
  final cTelefono = TextEditingController();
  final cCorreo = TextEditingController();
  bool warnedEdit = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => loading = true);

    // Prefill store
    final p = await SessionStore().getProfile();
    final nombre = (p['usNombre'] ?? '').toString();
    final ap = (p['usAPaterno'] ?? '').toString();
    final am = (p['usAMaterno'] ?? '').toString();
    cNombre.text = ('$nombre $ap $am').trim();
    cTelefono.text = (p['usTelefono'] ?? '').toString();
    cCorreo.text = (p['usCorreo'] ?? '').toString();

    try {
      sedes = await TicketCatalogService(dio).sites(healthOnly: true);
      if (!mounted) return;
      if (sedes.isNotEmpty) {
        csId = sedes.first['csId'] as int;
        await _loadSiteEquipment();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadSiteEquipment() async {
    final id = csId;
    selectedEqIds.clear();
    equipos = [];
    if (id == null) return;
    setState(() => loading = true);
    try {
      final items = await TicketCatalogService(
        dio,
      ).equipment(id, healthOnly: true);
      if (mounted && id == csId) setState(() => equipos = items);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(Object error) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppHttp.friendlyError(error)),
          action: SnackBarAction(label: 'Reintentar', onPressed: _init),
        ),
      );
  }

  @override
  void dispose() {
    cNombre.dispose();
    cTelefono.dispose();
    cCorreo.dispose();
    super.dispose();
  }

  void _warnEdit() {
    if (warnedEdit) return;
    warnedEdit = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '⚠️ Cambiar la información de contacto puede alterar tiempos y respuestas del ticket.',
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get equiposFiltrados {
    return equipos.where((e) => int.tryParse('${e['csId']}') == csId).toList();
  }

  String _fmtDateTime(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:00';
  }

  Future<void> _pickFechaHora() async {
    final date = await showDatePicker(
      context: context,
      initialDate: fechaHora,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fechaHora),
    );
    if (time == null) return;

    setState(() {
      fechaHora = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (csId == null) return;
    if (selectedEqIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos 1 equipo')),
      );
      return;
    }

    setState(() => sending = true);
    try {
      final items =
          equiposFiltrados
              .where(
                (e) =>
                    selectedEqIds.contains(int.tryParse('${e['peId']}') ?? -1),
              )
              .map(
                (e) => {
                  'eqId': int.tryParse('${e['eqId']}'),
                  'peId': int.tryParse('${e['peId']}'),
                },
              )
              .toList();

      final form = {
        'csId': csId,
        'hcFechaHora': _fmtDateTime(fechaHora),
        'hcDuracionMins': duracionMins,
        'hcNombreContacto': cNombre.text.trim(),
        'hcNumeroContacto': cTelefono.text.trim(),
        'hcCorreoContacto': cCorreo.text.trim(),
        'items': items,
      };

      final res = await dio.post(
        TicketCatalogService(dio).endpoint('health_create'),
        data: form,
      );
      final j = res.data;

      if (j is Map && j['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Health Check #${j['hcId']} programado correctamente.',
            ),
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        final msg =
            (j is Map ? (j['error'] ?? j['message']) : 'Error').toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MRSColors.bg,
      appBar: AppBar(
        backgroundColor: MRSColors.bg,
        title: const Text(
          'Health Check',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  const MRPageIntro(
                    eyebrow: 'Revisión preventiva',
                    title: 'Anticípate a las fallas.',
                    subtitle:
                        'Selecciona la sede, los equipos y una ventana para revisar tu operación.',
                  ),
                  const SizedBox(height: 20),
                  const MRSectionHeading(
                    title: 'Ubicación y equipo',
                    subtitle: 'Selecciona dónde realizaremos el servicio',
                  ),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sede',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<int>(
                          value: csId,
                          isExpanded: true,
                          itemHeight: null,
                          underline: const SizedBox.shrink(),
                          hint: const Text('Selecciona una sede'),
                          selectedItemBuilder:
                              (context) =>
                                  sedes
                                      .map(
                                        (s) => Text(
                                          '${s['csNombre'] ?? ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                      .toList(),
                          items:
                              sedes
                                  .map(
                                    (s) => DropdownMenuItem<int>(
                                      value: s['csId'] as int,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text('${s['csNombre'] ?? ''}'),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() => csId = value);
                            _loadSiteEquipment();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Equipo',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        ...equiposFiltrados.map((e) {
                          final eqId = int.tryParse('${e['peId']}') ?? -1;
                          final checked = selectedEqIds.contains(eqId);

                          final modelo =
                              '${e['eqModelo'] ?? ''} ${e['eqVersion'] ?? ''}'
                                  .trim();
                          final sn = (e['peSN'] ?? '').toString();
                          final marca = (e['maNombre'] ?? '').toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (checked) {
                                    selectedEqIds.remove(eqId);
                                  } else {
                                    selectedEqIds.add(eqId);
                                  }
                                });
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          modelo,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'SN: $sn • $marca',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Health check restantes: 1',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: checked ? mrPurple : Colors.white,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: mrPurple,
                                        width: 2,
                                      ),
                                    ),
                                    child:
                                        checked
                                            ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _card(
                    ListTile(
                      leading: const Icon(
                        Icons.calendar_month_rounded,
                        color: mrPurple,
                      ),
                      title: Text(
                        '${_fmtDateTime(fechaHora)} (${(duracionMins / 60).round()}h)',
                      ),
                      onTap: _pickFechaHora,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _card(
                    Column(
                      children: [
                        TextField(
                          controller: cNombre,
                          onChanged: (_) => _warnEdit(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_rounded),
                            labelText: 'Nombre de Contacto',
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: cTelefono,
                          onChanged: (_) => _warnEdit(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.phone_rounded),
                            labelText: 'Número de contacto',
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: cCorreo,
                          onChanged: (_) => _warnEdit(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.mail_rounded),
                            labelText: 'Correo Electrónico',
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MRSColors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: sending ? null : _submit,
                      child: Text(
                        sending ? 'Programando…' : 'Programar Health Check',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _card(Widget child) {
    return MRSectionCard(padding: const EdgeInsets.all(16), child: child);
  }
}
