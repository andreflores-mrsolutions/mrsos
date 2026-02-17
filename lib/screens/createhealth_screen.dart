import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mrsos/services/session_store.dart';
import 'package:mrsos/services/app_http.dart'; // tu singleton dio

class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({super.key, required this.baseUrl});
  final String baseUrl; // http://192.168.3.7/php

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

    // equipos/sedes
    final res = await dio.get('${widget.baseUrl}/obtener_equipo_poliza.php');
    final data = res.data;

    if (data is Map && data['success'] == true) {
      final list = (data['equipos'] as List? ?? []).cast<dynamic>();
      equipos = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final map = <int, String>{};
      for (final e in equipos) {
        final id = int.tryParse('${e['csId']}');
        final name = (e['csNombre'] ?? '').toString();
        if (id != null && name.isNotEmpty) map[id] = name;
      }

      sedes =
          map.entries.map((x) => {'csId': x.key, 'csNombre': x.value}).toList()
            ..sort(
              (a, b) =>
                  (a['csNombre'] as String).compareTo(b['csNombre'] as String),
            );

      if (sedes.isNotEmpty) csId = sedes.first['csId'] as int;
    }

    if (!mounted) return;
    setState(() => loading = false);
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
                    selectedEqIds.contains(int.tryParse('${e['eqId']}') ?? -1),
              )
              .map(
                (e) => {
                  'eqId': int.tryParse('${e['eqId']}'),
                  'peId': int.tryParse('${e['peId']}'),
                },
              )
              .toList();

      final form = FormData.fromMap({
        'csId': csId,
        'hcFechaHora': _fmtDateTime(fechaHora),
        'hcDuracionMins': duracionMins,
        'hcNombreContacto': cNombre.text.trim(),
        'hcNumeroContacto': cTelefono.text.trim(),
        'hcCorreoContacto': cCorreo.text.trim(),
        'equipos': jsonEncode(items),
      });

      final res = await dio.post(
        '${widget.baseUrl}/crear_health_check.php',
        data: form,
      );
      final j = res.data;

      if (j is Map && j['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Health Check creado. Tickets: ${(j['tickets'] as List).length}',
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
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Health Check',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                children: [
                  _card(
                    Row(
                      children: [
                        const Icon(Icons.apartment_rounded, color: mrPurple),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Grupos/Sedes',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        DropdownButton<int>(
                          value: csId,
                          underline: const SizedBox.shrink(),
                          items:
                              sedes
                                  .map(
                                    (s) => DropdownMenuItem<int>(
                                      value: s['csId'] as int,
                                      child: Text(
                                        (s['csNombre'] ?? '').toString(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            setState(() {
                              csId = v;
                              selectedEqIds.clear();
                            });
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
                          final eqId = int.tryParse('${e['eqId']}') ?? -1;
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
                        const Divider(height: 1),
                        TextField(
                          controller: cTelefono,
                          onChanged: (_) => _warnEdit(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.phone_rounded),
                            labelText: 'Número de contacto',
                            border: InputBorder.none,
                          ),
                        ),
                        const Divider(height: 1),
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
                        backgroundColor: mrPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: sending ? null : _submit,
                      child: Text(
                        sending ? 'Creando…' : 'Crear Ticket',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
