import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/services/session_store.dart';

import 'change_password_webview.dart'; // reutilízalo para WebView genérico (o crea uno simple)

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key, required this.baseUrl});
  final String
  baseUrl; // ej: https://yellow-chicken-910471.hostingersite.com/php

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  bool _loading = true;
  bool _submitting = false;

  // Perfil (prefill)
  String usNombre = '';
  String usAPaterno = '';
  String usAMaterno = '';
  String usCorreo = '';
  String usTelefono = '';

  // Campos editables del ticket
  late TextEditingController cNombre;
  late TextEditingController cTelefono;
  late TextEditingController cCorreo;
  late TextEditingController cDescripcion;

  bool _userEditedContactData = false;

  // Data sedes/equipos
  List<Map<String, dynamic>> _equipos = [];
  List<Map<String, dynamic>> _sedes = [];

  int? _selectedCsId;
  Map<String, dynamic>? _selectedEquipo;

  // Criticidad (Nivel 1..3)
  String _criticidad = '3';

  // Logs opcionales
  PlatformFile? _logFile;

  Dio get _dio {
    // si tú lo tienes como singleton:
    return AppHttp.I.dio;
    // aquí lo dejo directo para que lo conectes a tu AppHttp:
  }

  @override
  void initState() {
    super.initState();
    cNombre = TextEditingController();
    cTelefono = TextEditingController();
    cCorreo = TextEditingController();
    cDescripcion = TextEditingController();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    // 1) Prefill desde SessionStore
    final p = await SessionStore().getProfile();
    usNombre = (p['usNombre'] ?? '').toString();
    usAPaterno = (p['usAPaterno'] ?? '').toString();
    usAMaterno = (p['usAMaterno'] ?? '').toString();
    usCorreo = (p['usCorreo'] ?? '').toString();
    usTelefono = (p['usTelefono'] ?? '').toString();

    cNombre.text =
        '${usNombre.trim()} ${usAPaterno.trim()} ${usAMaterno.trim()}'.trim();
    cTelefono.text = usTelefono;
    cCorreo.text = usCorreo;

    // 2) Traer equipos/sedes
    await _loadEquiposPoliza();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadEquiposPoliza() async {
    // GET /obtener_equipo_poliza.php
    final res = await _dio.get(
      '${widget.baseUrl}/obtener_equipo_poliza.php',
      options: Options(responseType: ResponseType.json),
    );

    final data = res.data;
    if (data is Map && data['success'] == true) {
      final list = (data['equipos'] as List? ?? []).cast<dynamic>();
      _equipos = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Armar sedes únicas (csId/csNombre)
      final map = <int, String>{};
      for (final e in _equipos) {
        final csId = int.tryParse((e['csId'] ?? '').toString());
        final csNombre = (e['csNombre'] ?? '').toString();
        if (csId != null && csNombre.isNotEmpty) {
          map[csId] = csNombre;
        }
      }

      _sedes =
          map.entries.map((x) => {'csId': x.key, 'csNombre': x.value}).toList()
            ..sort(
              (a, b) =>
                  (a['csNombre'] as String).compareTo(b['csNombre'] as String),
            );

      // Default: primera sede
      if (_sedes.isNotEmpty) {
        _selectedCsId = _sedes.first['csId'] as int;
      }

      // Default equipo: primero de esa sede
      _syncEquipoDefault();
    } else {
      throw Exception(
        (data is Map ? data['error'] : null) ?? 'No se pudo cargar equipos',
      );
    }
  }

  void _syncEquipoDefault() {
    if (_selectedCsId == null) {
      _selectedEquipo = null;
      return;
    }
    final filtered =
        _equipos.where((e) {
          final csId = int.tryParse((e['csId'] ?? '').toString());
          return csId == _selectedCsId;
        }).toList();

    _selectedEquipo = filtered.isNotEmpty ? filtered.first : null;
  }

  Future<void> _pickLogs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['log', 'txt', 'zip', 'rar', '7z', 'tar', 'gz'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _logFile = result.files.first);
  }

  void _openHelpLogs() {
    if (_selectedEquipo == null) return;

    final marca = (_selectedEquipo?['maNombre'] ?? '').toString();
    final modelo =
        ((_selectedEquipo?['eqModelo'] ?? '')).toString() +
        ((_selectedEquipo?['eqVersion'] ?? '').toString().trim().isEmpty
            ? ''
            : ' ${_selectedEquipo?['eqVersion']}'.toString());

    final url =
        Uri.parse(
          'https://yellow-chicken-910471.hostingersite.com/dashboard/ayuda_logs.php',
        ).replace(queryParameters: {'marca': marca, 'modelo': modelo}).toString();

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChangePasswordWebViewScreen(url: url)),
    );
  }

  Future<void> _submit() async {
    if (_selectedEquipo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un equipo')));
      return;
    }
    if (cDescripcion.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Describe el problema')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final eq = _selectedEquipo!;
      final csId = _selectedCsId;
      final peId = int.tryParse((eq['peId'] ?? '').toString());
      final eqId = int.tryParse((eq['eqId'] ?? '').toString());

      // 1) Crear ticket (sin logs primero)
      // Tu backend maneja sesión y crea tiId; devuelve JSON con success/tiId:contentReference[oaicite:2]{index=2}
      final form = FormData.fromMap({
        'csId': csId,
        'peId': peId,
        'eqId': eqId,
        'descripcion': cDescripcion.text.trim(),
        'severidad': _criticidad,
        'contacto': cNombre.text.trim(),
        'telefono': cTelefono.text.trim(),
        'email': cCorreo.text.trim(),
        // si tu crear_ticket.php usa otros nombres, lo ajustamos a tu PHP real.
      });

      final res = await _dio.post(
        '${widget.baseUrl}/crear_ticket.php',
        data: form,
        options: Options(responseType: ResponseType.json),
      );
      final json = res.data;

      if (json is! Map || json['success'] != true) {
        final msg =
            (json is Map ? (json['error'] ?? json['message']) : null) ??
            'No se pudo crear el ticket';
        throw Exception(msg.toString());
      }

      final tiId = int.tryParse((json['tiId'] ?? '').toString());

      // 2) Si hay logs, subirlos (como hace tu web: tiId + logs a subir_logs.php):contentReference[oaicite:3]{index=3}
      if (tiId != null && _logFile != null && _logFile!.path != null) {
        final fd = FormData.fromMap({
          'tiId': tiId,
          'logs': await MultipartFile.fromFile(
            _logFile!.path!,
            filename: _logFile!.name,
          ),
        });

        final up = await _dio.post(
          '${widget.baseUrl}/subir_logs.php',
          data: fd,
          options: Options(responseType: ResponseType.json),
        );
        final upJson = up.data;

        if (upJson is Map && upJson['success'] != true) {
          // Ticket ya existe; solo avisamos que logs fallaron.
          final msg =
              (upJson['error'] ?? 'Ticket creado, pero falló la carga de logs')
                  .toString();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket creado correctamente')),
      );
      Navigator.pop(context); // volver (por ahora)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _markEdited() {
    if (!_userEditedContactData) {
      setState(() => _userEditedContactData = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Cambiar la información de contacto puede alterar tiempos y respuestas del ticket.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final equiposFiltrados =
        _equipos.where((e) {
          final csId = int.tryParse((e['csId'] ?? '').toString());
          return csId == _selectedCsId;
        }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Nuevo Ticket',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  children: [
                    // Sede
                    _Card(
                      child: Row(
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
                            value: _selectedCsId,
                            underline: const SizedBox.shrink(),
                            items:
                                _sedes
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
                                _selectedCsId = v;
                                _syncEquipoDefault();
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Equipo (filtrado por sede)
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Equipo',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<Map<String, dynamic>>(
                            value: _selectedEquipo,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items:
                                equiposFiltrados.map((e) {
                                  final modelo =
                                      '${e['eqModelo'] ?? ''} ${e['eqVersion'] ?? ''}'
                                          .trim();
                                  final sn = (e['peSN'] ?? '').toString();
                                  final marca =
                                      (e['maNombre'] ?? '').toString();
                                  return DropdownMenuItem(
                                    value: e,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          modelo,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
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
                                      ],
                                    ),
                                  );
                                }).toList(),
                            onChanged:
                                (v) => setState(() => _selectedEquipo = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Criticidad
                    _Card(
                      child: Row(
                        children: [
                          const Icon(Icons.brightness_1, color: Colors.red),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Criticidad',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          DropdownButton<String>(
                            value: _criticidad,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: '1',
                                child: Text('Nivel 1'),
                              ),
                              DropdownMenuItem(
                                value: '2',
                                child: Text('Nivel 2'),
                              ),
                              DropdownMenuItem(
                                value: '3',
                                child: Text('Nivel 3'),
                              ),
                            ],
                            onChanged:
                                (v) => setState(() => _criticidad = v ?? '3'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Descripción
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Descripción del problema',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: cDescripcion,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Describe el problema…',
                              filled: true,
                              fillColor: const Color(0xFFF2F4FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Contacto prellenado + aviso si edita
                    _Card(
                      child: Column(
                        children: [
                          _InputLine(
                            icon: Icons.person_rounded,
                            label: 'Nombre de Contacto',
                            controller: cNombre,
                            onEdited: _markEdited,
                          ),
                          const SizedBox(height: 10),
                          _InputLine(
                            icon: Icons.phone_rounded,
                            label: 'Número de contacto',
                            controller: cTelefono,
                            keyboardType: TextInputType.phone,
                            onEdited: _markEdited,
                          ),
                          const SizedBox(height: 10),
                          _InputLine(
                            icon: Icons.mail_rounded,
                            label: 'Correo Electrónico',
                            controller: cCorreo,
                            keyboardType: TextInputType.emailAddress,
                            onEdited: _markEdited,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Logs opcional + Ayuda
                    _Card(
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Logs (opcional)',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            tooltip: '¿Cómo extraer los logs?',
                            onPressed: _openHelpLogs,
                            icon: const Icon(
                              Icons.help_outline_rounded,
                              color: mrPurple,
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            onPressed: _pickLogs,
                            child: Text(
                              _logFile == null
                                  ? 'Seleccionar Archivos'
                                  : '1 archivo',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Crear ticket
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
                        onPressed: _submitting ? null : _submit,
                        child: Text(
                          _submitting ? 'Creando…' : 'Crear Ticket',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
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

class _InputLine extends StatelessWidget {
  const _InputLine({
    required this.icon,
    required this.label,
    required this.controller,
    required this.onEdited,
    this.keyboardType,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final VoidCallback onEdited;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF200F4C)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: (_) => onEdited(),
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: const Color(0xFFF2F4FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
