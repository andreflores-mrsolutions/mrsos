import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mrsos/services/app_http.dart';
import '../services/ticket_catalog_service.dart';
import 'package:mrsos/widget/colors.dart';
import 'package:mrsos/widget/mr_theme.dart';
import 'package:mrsos/widget/mr_components.dart';

import 'log_guides_screen.dart';
import '../widget/equipment_picker.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key, required this.baseUrl});
  final String baseUrl; // ej: https://mrsos.com.mx/php

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  bool _loading = true;
  bool _submitting = false;
  int _catalogGeneration = 0;
  String _role = '';
  bool get _internal => ['MRSA', 'MRA'].contains(_role);
  List<Map<String, dynamic>> _clients = [], _responsibles = [];
  int? _clientId, _responsibleId;

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
    Map<String, dynamic> p;
    try {
      p = AppHttp.jsonMap((await _dio.get('/me.php')).data);
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppHttp.friendlyError(error))));
      }
      return;
    }
    if (!mounted) return;
    _role = '${p['usRol'] ?? p['rol'] ?? ''}';
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

  @override
  void dispose() {
    cNombre.dispose();
    cTelefono.dispose();
    cCorreo.dispose();
    cDescripcion.dispose();
    super.dispose();
  }

  Future<void> _loadEquiposPoliza() async {
    try {
      final catalog = TicketCatalogService(_dio);
      if (_internal) {
        final clients = await catalog.clients();
        if (mounted) setState(() => _clients = clients);
        return;
      }
      if (_role != 'CLI') throw StateError('Tu rol no permite crear tickets.');
      _sedes = await catalog.sites();
      if (!mounted) return;
      _selectedCsId = _sedes.isEmpty ? null : _sedes.first['csId'] as int;
      if (_selectedCsId != null) await _loadSiteEquipment();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppHttp.friendlyError(error)),
            action: SnackBarAction(label: 'Reintentar', onPressed: _init),
          ),
        );
    }
  }

  Future<void> _loadSiteEquipment() async {
    final generation = ++_catalogGeneration;
    final id = _selectedCsId;
    _selectedEquipo = null;
    _equipos = [];
    _responsibles = [];
    _responsibleId = null;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final catalog = TicketCatalogService(_dio);
      final clientId = _internal ? _clientId : null;
      if (_internal && clientId == null) return;
      final list = await catalog.equipment(id, clientId: clientId);
      final users =
          _internal
              ? await catalog.responsibleUsers(clientId!, id)
              : <Map<String, dynamic>>[];
      if (!mounted || generation != _catalogGeneration) return;
      setState(() {
        _equipos = list;
        _responsibles = users;
      });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppHttp.friendlyError(error)),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _loadSiteEquipment,
            ),
          ),
        );
    } finally {
      if (mounted && generation == _catalogGeneration)
        setState(() => _loading = false);
    }
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

  Future<void> _selectClient(int? value) async {
    final generation = ++_catalogGeneration;
    setState(() {
      _clientId = value;
      _selectedCsId = null;
      _selectedEquipo = null;
      _sedes = [];
      _equipos = [];
      _responsibles = [];
      _responsibleId = null;
      _loading = true;
    });
    try {
      if (value == null) return;
      final sites = await TicketCatalogService(_dio).sites(clientId: value);
      if (mounted && generation == _catalogGeneration)
        setState(() => _sedes = sites);
    } catch (e) {
      if (mounted && generation == _catalogGeneration)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppHttp.friendlyError(e))));
    } finally {
      if (mounted && generation == _catalogGeneration)
        setState(() => _loading = false);
    }
  }

  void _openHelpLogs() {
    if (_selectedEquipo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => LogGuidesScreen(
              peId: int.tryParse('${_selectedEquipo?['peId']}'),
            ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting || _loading) return;
    if (!['CLI', 'MRSA', 'MRA'].contains(_role) ||
        (_internal && (_clientId == null || _responsibleId == null))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona el cliente y su usuario responsable autorizado.',
          ),
        ),
      );
      return;
    }
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
      // The server derives the actor from the PHP session and validates scope.
      final form = {
        if (_internal) 'clId': _clientId,
        if (_internal) 'usIdCliente': _responsibleId,
        'csId': csId,
        'peId': peId,
        'eqId': eqId,
        'tiDescripcion': cDescripcion.text.trim(),
        'tiNivelCriticidad': _criticidad,
        'tiNombreContacto': cNombre.text.trim(),
        'tiNumeroContacto': cTelefono.text.trim(),
        'tiCorreoContacto': cCorreo.text.trim(),
        'tiTipoTicket': 'Servicio',
      };

      final res = await _dio.post(
        TicketCatalogService(
          _dio,
        ).endpoint('ticket_create', internal: _internal),
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

      // Creation is already committed: upload failures must never offer to
      // create the ticket again. Logs can be retried from the ticket detail.
      String? uploadWarning;
      if (tiId != null && _logFile?.path != null) {
        try {
          if (_logFile!.size > 25 * 1024 * 1024)
            throw StateError('El límite por log es 25 MB.');
          final fd = FormData.fromMap({'tiId': tiId});
          fd.files.add(
            MapEntry(
              'files[]',
              await MultipartFile.fromFile(
                _logFile!.path!,
                filename: _logFile!.name,
              ),
            ),
          );
          await _dio.post(
            TicketCatalogService(_dio).endpoint('logs_upload'),
            data: fd,
          );
        } catch (error) {
          uploadWarning =
              'Ticket #$tiId creado. Adjunta los logs desde su detalle: ${AppHttp.friendlyError(error)}';
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadWarning ?? 'Ticket #$tiId creado correctamente'),
        ),
      );
      Navigator.pop(context, true);
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
      backgroundColor: MRSColors.bg,
      appBar: AppBar(
        backgroundColor: MRSColors.bg,
        title: const Text(
          'Nuevo ticket',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  children: [
                    const MRPageIntro(
                      eyebrow: 'Nueva solicitud',
                      title: 'Vamos a resolverlo.',
                      subtitle:
                          'Cuéntanos qué sucede. Tu equipo de soporte se encargará del siguiente paso.',
                    ),
                    const SizedBox(height: 20),
                    const MRSectionHeading(
                      title: 'Ubicación y equipo',
                      subtitle: 'Selecciona dónde realizaremos el servicio',
                    ),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sede',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (_internal) ...[
                            DropdownButton<int>(
                              value: _clientId,
                              isExpanded: true,
                              hint: const Text('Selecciona el cliente'),
                              items:
                                  _clients
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: int.parse('${c['clId']}'),
                                          child: Text(
                                            '${c['clNombre']}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: _submitting ? null : _selectClient,
                            ),
                          ],
                          const SizedBox(height: 8),
                          DropdownButton<int>(
                            value: _selectedCsId,
                            isExpanded: true,
                            itemHeight: null,
                            underline: const SizedBox.shrink(),
                            hint: const Text('Selecciona una sede'),
                            selectedItemBuilder:
                                (context) =>
                                    _sedes
                                        .map(
                                          (s) => Text(
                                            '${s['csNombre'] ?? ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )
                                        .toList(),
                            items:
                                _sedes
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
                            onChanged:
                                _submitting
                                    ? null
                                    : (value) {
                                      setState(() => _selectedCsId = value);
                                      _loadSiteEquipment();
                                    },
                          ),
                          if (_internal)
                            DropdownButton<int>(
                              value: _responsibleId,
                              isExpanded: true,
                              hint: const Text(
                                'Usuario responsable de esta sede',
                              ),
                              items:
                                  _responsibles
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: int.parse('${u['usId']}'),
                                          child: Text(
                                            '${u['nombre']}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  _submitting
                                      ? null
                                      : (id) {
                                        if (id == null) return;
                                        final user = _responsibles.firstWhere(
                                          (u) => '${u['usId']}' == '$id',
                                        );
                                        setState(() {
                                          _responsibleId = id;
                                          cNombre.text =
                                              '${user['nombre'] ?? ''}';
                                          cCorreo.text =
                                              '${user['correo'] ?? ''}';
                                          cTelefono.text =
                                              '${user['telefono'] ?? ''}';
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
                          OutlinedButton.icon(
                            onPressed:
                                _loading || _submitting
                                    ? null
                                    : () async {
                                      final generation = _catalogGeneration;
                                      final equipo = await pickEquipment(
                                        context,
                                        equiposFiltrados,
                                      );
                                      if (mounted &&
                                          generation == _catalogGeneration &&
                                          equipo != null) {
                                        setState(
                                          () => _selectedEquipo = equipo,
                                        );
                                      }
                                    },
                            icon: const Icon(Icons.search),
                            label: Text(
                              _selectedEquipo == null
                                  ? 'Buscar y seleccionar equipo'
                                  : '${_selectedEquipo!['eqModelo'] ?? 'Cambiar equipo'}',
                            ),
                          ),
                          if (_selectedEquipo != null)
                            Text(
                              'SN ${_selectedEquipo!['peSN'] ?? 'Sin registrar'}',
                              style: const TextStyle(
                                color: MRSColors.muted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Criticidad
                    _Card(
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            color:
                                _criticidad == '1'
                                    ? MRSColors.dangerText
                                    : _criticidad == '2'
                                    ? MRSColors.warningText
                                    : MRSColors.successText,
                          ),
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

                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Logs · opcional',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                tooltip: '¿Cómo extraer los logs?',
                                onPressed: _openHelpLogs,
                                icon: const Icon(
                                  Icons.help_outline_rounded,
                                  color: MRSColors.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _pickLogs,
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              size: 20,
                            ),
                            label: Text(
                              _logFile?.name ?? 'Adjuntar archivo',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                          backgroundColor: MRSColors.teal,
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
    return MRSectionCard(padding: const EdgeInsets.all(16), child: child);
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
        Icon(icon, color: const Color(0xFF0B1B46)),
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
