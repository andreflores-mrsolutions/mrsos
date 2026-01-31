import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/services/onboarding_service.dart';

import '../services/profile_service.dart';
import '../services/session_store.dart';
import 'home_screen.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({
    super.key,
    required this.user,
    required this.forceChangePass,
  });

  final Map<String, dynamic> user;
  final bool forceChangePass;

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _page = PageController();

  // ✅ Estado del usuario (editable en el flujo)
  late String usNombre;
  late String usAPaterno;
  late String usAMaterno;
  late String usTelefono;
  late String usCorreo;
  late String usUsername;
  late int usId;

  // Password
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();

  // Avatar
  File? _avatarFile;

  bool _saving = false;

  // Service (ajusta tu baseUrl/paths si ya los tienes en AppHttp)
  late final OnboardingService _svc;

  @override
  void initState() {
    super.initState();
    _svc = OnboardingService(
      dio: AppHttp.I.dio,
      savePath: '/guardar_onboarding_app.php',
    );

    usId = int.tryParse('${widget.user['usId'] ?? 0}') ?? 0;

    usNombre = '${widget.user['usNombre'] ?? ''}';
    usAPaterno = '${widget.user['usAPaterno'] ?? ''}';
    usAMaterno = '${widget.user['usAMaterno'] ?? ''}';
    usTelefono = '${widget.user['usTelefono'] ?? ''}';
    usCorreo = '${widget.user['usCorreo'] ?? ''}';
    usUsername = '${widget.user['usUsername'] ?? ''}';
  }

  @override
  void dispose() {
    _page.dispose();
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  BoxDecoration get _bg => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF3F0FF),
        Color(0xFFFFFFFF),
        Color(0xFFF7F6FF),
        Color(0xFFFFFFFF),
      ],
      stops: [0.0, 0.40, 0.75, 1.0],
    ),
  );

  // === Edición individual (igual que usuario_detail_screen.dart) ===
  Future<void> _editarTexto({
    required String titulo,
    required String valorInicial,
    required ValueChanged<String> onSave,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 80,
  }) async {
    final c = TextEditingController(text: valorInicial);

    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: c,
                    keyboardType: keyboardType,
                    maxLength: maxLength,
                    decoration: InputDecoration(
                      hintText: titulo,
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF7F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, c.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF200F4C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (v == null) return;
    onSave(v);
  }

  bool _validUsername(String s) {
    final re = RegExp(r'^[A-Za-z0-9_-]{3,20}$');
    return re.hasMatch(s);
  }

  bool _validPassword(String p) {
    if (p.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(p)) return false;
    if (!RegExp(r'[a-z]').hasMatch(p)) return false;
    if (!RegExp(r'[0-9]').hasMatch(p)) return false;
    if (!RegExp(r'[!@#$%^&*()_\-+={}[\]:;"\<>,.?/~`\\|]').hasMatch(p)) {
      return false;
    }
    return true;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (x == null) return;
    setState(() => _avatarFile = File(x.path));
  }

  Future<void> _guardarOnboarding() async {
    final changingPass = _pass1.text.isNotEmpty || _pass2.text.isNotEmpty;

    if (usNombre.trim().isEmpty ||
        usAPaterno.trim().isEmpty ||
        usCorreo.trim().isEmpty) {
      _snack('Nombre, apellido y correo son obligatorios', isError: true);
      return;
    }
    if (!_validUsername(usUsername.trim())) {
      _snack(
        'Nombre de usuario inválido (3-20, letras/números, - o _)',
        isError: true,
      );
      return;
    }

    final p1 = _pass1.text;
    final p2 = _pass2.text;
    if (p1.isEmpty || p2.isEmpty || p1 != p2) {
      _snack('Las contraseñas no coinciden o están vacías', isError: true);
      return;
    }
    if (!_validPassword(p1)) {
      _snack(
        'La contraseña no cumple requisitos (min 8, mayúscula, minúscula, número y especial)',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final r = await _svc.save(
        usId: usId,
        usNombre: usNombre,
        usAPaterno: usAPaterno,
        usAMaterno: usAMaterno,
        usCorreo: usCorreo,
        usTelefono: usTelefono,
        usUsername: usUsername,
        pass1: changingPass ? _pass1.text : '',
        pass2: changingPass ? _pass2.text : '',
      );

      if (!mounted) return;

      if (!r.success) {
        _snack(
          r.message.isNotEmpty ? r.message : 'No se pudo guardar',
          isError: true,
        );
        return;
      }

      final u = r.user ?? widget.user;

      // Guarda sesión:
      await SessionStore.saveLogin(
        usId: '${u['usId'] ?? usId}',
        userName: '${u['usNombre'] ?? usNombre}',
        usAPaterno: '${u['usAPaterno'] ?? usAPaterno}',
        usAMaterno: '${u['usAMaterno'] ?? usAMaterno}',
        usCorreo: '${u['usCorreo'] ?? usCorreo}',
        usTelefono: '${u['usTelefono'] ?? usTelefono}',
        usUsername: '${u['usUsername'] ?? usUsername}',
        usImagen: u['usImagen']?.toString(),
        ucrRol: '${u['ucrRol'] ?? ''}',
        czId: u['czId'] != null ? int.tryParse('${u['czId']}') : null,
        csId: u['csId'] != null ? int.tryParse('${u['csId']}') : null,
        ucrClId: u['ucrClId'] != null ? int.tryParse('${u['ucrClId']}') : null,
      );

      // Ir a Home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (_) => HomeDashboardScreen(
                usId: '$usId',
                userName: usNombre.isNotEmpty ? usNombre : 'Usuario',
              ),
        ),
        (r) => false,
      );
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _primary(String text, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: _saving ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2F51FF),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child:
          _saving
              ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
    ),
  );

  Widget _secondary(String text, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: _saving ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE9EDFF),
        foregroundColor: Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _bg,
        child: SafeArea(
          child: PageView(
            controller: _page,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _IntroScreen(
                title: 'Soporte Inteligente,\nsin fricción.',
                subtitle:
                    'Centraliza tickets, seguimiento por procesos,\nreuniones y carga guiada de logs.\nTodo en una sola vista clara.',
                showStats: true,
                stat1Label: 'Experiencia',
                stat1Value: '+25 años',
                stat2Label: 'Clientes',
                stat2Value: '+100',
                stat3Label: 'Proyectos',
                stat3Value: '+500',
                buttonText: 'Comenzar',
                secondaryText: 'En Otro momento',
                onNext:
                    () => _page.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                onBack: () => Navigator.pop(context),
              ),

              _IntroScreen(
                title: 'Visibilidad Total\nTus Tikets\nTu Póliza\nTu Control',
                subtitle:
                    'Consulta el estado de tus casos,\nla información de tus equipos y\nlos detalles de tu póliza en una sola app.\nTodo lo que necesitas para tomar\ndecisiones rápidas, al alcance de tu mano.',
                buttonText: 'Continuar',
                secondaryText: 'Atras',
                onNext:
                    () => _page.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                onBack:
                    () => _page.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
              ),

              // ✅ Paso: verificar/editar datos (ESTILO IGUAL usuario_detail)
              OnboardingVerifyDataStep(
                nombre: usNombre,
                apaterno: usAPaterno,
                amaterno: usAMaterno,
                telefono: usTelefono,
                correo: usCorreo,
                onEditNombre:
                    () => _editarTexto(
                      titulo: 'Nombre del Contacto',
                      valorInicial: usNombre,
                      onSave: (v) => setState(() => usNombre = v),
                    ),
                onEditAPaterno:
                    () => _editarTexto(
                      titulo: 'Apellido Paterno',
                      valorInicial: usAPaterno,
                      onSave: (v) => setState(() => usAPaterno = v),
                    ),
                onEditAMaterno:
                    () => _editarTexto(
                      titulo: 'Apellido Materno',
                      valorInicial: usAMaterno,
                      onSave: (v) => setState(() => usAMaterno = v),
                    ),
                onEditTelefono:
                    () => _editarTexto(
                      titulo: 'Número del contacto',
                      valorInicial: usTelefono,
                      keyboardType: TextInputType.phone,
                      maxLength: 20,
                      onSave: (v) => setState(() => usTelefono = v),
                    ),
                onEditCorreo:
                    () => _editarTexto(
                      titulo: 'Correo Electrónico',
                      valorInicial: usCorreo,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 120,
                      onSave: (v) => setState(() => usCorreo = v),
                    ),
                onContinue:
                    () => _page.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                onBack:
                    () => _page.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
              ),

              // ✅ Paso: username
              _UsernameStep(
                initial: usUsername,
                onBack:
                    () => _page.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                onContinue: (val) {
                  if (!_validUsername(val.trim())) {
                    _snack(
                      'Usa letras, números, guion (-) o guion bajo (_)',
                      isError: true,
                    );
                    return;
                  }
                  setState(() => usUsername = val.trim());
                  _page.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
              ),

              // ✅ Paso: password
              _PasswordStep(
                pass1: _pass1,
                pass2: _pass2,
                onBack:
                    () => _page.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                onContinue:
                    () => _page.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
              ),

              // ✅ Paso: avatar (opcional)
              _AvatarStep(
                avatarFile: _avatarFile,
                onPick: _pickAvatar,
                onBack:
                    () => _page.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                onContinue:
                    () => _page.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
              ),

              // ✅ Final
              _DoneStep(
                onBack:
                    () => _page.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                onFinish: _guardarOnboarding,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ====== Widgets de pasos ====== */

class OnboardingVerifyDataStep extends StatelessWidget {
  const OnboardingVerifyDataStep({
    super.key,
    required this.nombre,
    required this.apaterno,
    required this.amaterno,
    required this.telefono,
    required this.correo,
    required this.onEditNombre,
    required this.onEditAPaterno,
    required this.onEditAMaterno,
    required this.onEditTelefono,
    required this.onEditCorreo,
    required this.onContinue,
    required this.onBack,
  });

  final String nombre;
  final String apaterno;
  final String amaterno;
  final String telefono;
  final String correo;

  final VoidCallback onEditNombre;
  final VoidCallback onEditAPaterno;
  final VoidCallback onEditAMaterno;
  final VoidCallback onEditTelefono;
  final VoidCallback onEditCorreo;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    // Wrapper “anti-overflow”
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
              child: Column(
                children: [
                  const _MRLogo(),
                  const SizedBox(height: 8),
                  const Text(
                    'Verifiquemos tus datos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ayúdanos a confirmar tu información de\n'
                    'contacto. Esto facilitará la comunicación con\n'
                    'nuestro equipo de soporte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: Color(0xFF6B667A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ✅ Filas individuales estilo usuario_detail_screen.dart
                  _InfoCard(
                    icon: Icons.person_rounded,
                    label: 'Nombre del Contacto',
                    value: nombre,
                    trailingText: 'Editar',
                    onTap: onEditNombre,
                  ),
                  _InfoCard(
                    icon: Icons.person_outline_rounded,
                    label: 'Apellido Paterno',
                    value: apaterno,
                    trailingText: 'Editar',
                    onTap: onEditAPaterno,
                  ),
                  _InfoCard(
                    icon: Icons.person_outline_rounded,
                    label: 'Apellido Materno',
                    value: amaterno,
                    trailingText: 'Editar',
                    onTap: onEditAMaterno,
                  ),
                  _InfoCard(
                    icon: Icons.call_rounded,
                    label: 'Número del contacto',
                    value: telefono,
                    trailingText: 'Editar',
                    onTap: onEditTelefono,
                  ),
                  _InfoCard(
                    icon: Icons.mail_rounded,
                    label: 'Correo Electrónico',
                    value: correo,
                    trailingText: 'Editar',
                    onTap: onEditCorreo,
                  ),

                  const SizedBox(height: 8),

                  // Botones
                  _ActionButtonLike(
                    text: 'Continuar',
                    bg: const Color(0xFF2F51FF),
                    fg: Colors.white,
                    trailingArrow: true,
                    onTap: onContinue,
                  ),
                  const SizedBox(height: 12),
                  _ActionButtonLike(
                    text: 'Atras',
                    bg: const Color(0xFFE9EDFF),
                    fg: Colors.black87,
                    onTap: onBack,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UsernameStep extends StatefulWidget {
  const _UsernameStep({
    required this.initial,
    required this.onContinue,
    required this.onBack,
  });

  final String initial;
  final ValueChanged<String> onContinue;
  final VoidCallback onBack;

  @override
  State<_UsernameStep> createState() => _UsernameStepState();
}

class _UsernameStepState extends State<_UsernameStep> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      child: Column(
        children: [
          const _MRLogo(),
          const SizedBox(height: 10),
          const Text(
            'Elige tu nombre de usuario',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          const Text(
            'Es momento de elegir tu nombre de usuario. Será\n'
            'único y no podrás cambiarlo hasta más adelante,\n'
            'así que elígelo con cuidado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: Color(0xFF6B667A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          _InfoCard(
            icon: Icons.person_rounded,
            label: 'Nombre de usuario',
            value: _c.text,
            trailingText: 'Editar',
            onTap: () async {
              await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Nombre de usuario',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _c,
                              maxLength: 20,
                              decoration: InputDecoration(
                                hintText: 'Nombre de usuario',
                                counterText: '',
                                filled: true,
                                fillColor: const Color(0xFFF7F7FB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed:
                                    () =>
                                        Navigator.pop(context, _c.text.trim()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF200F4C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Guardar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Evita palabras ofensivas. Usa letras, números, guion (-) o\nguion bajo (_).',
              style: TextStyle(
                fontSize: 13.2,
                height: 1.35,
                color: Color(0xFF6B667A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          _ActionButtonLike(
            text: 'Continuar',
            bg: const Color(0xFF2F51FF),
            fg: Colors.white,
            trailingArrow: true,
            onTap: () => widget.onContinue(_c.text),
          ),
          const SizedBox(height: 12),
          _ActionButtonLike(
            text: 'Atras',
            bg: const Color(0xFFE9EDFF),
            fg: Colors.black87,
            onTap: widget.onBack,
          ),
        ],
      ),
    );
  }
}

class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.pass1,
    required this.pass2,
    required this.onContinue,
    required this.onBack,
  });

  final TextEditingController pass1;
  final TextEditingController pass2;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      child: Column(
        children: [
          const _MRLogo(),
          const SizedBox(height: 10),
          const Text(
            'Protejamos tu acceso',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          const Text(
            'Vamos a cambiar tu contraseña.\n'
            'Debe contener al menos:\n'
            'una letra mayúscula, una minúscula,\n'
            'un número y un carácter especial.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: Color(0xFF6B667A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          _PasswordField(label: 'Nueva Contraseña', controller: pass1),
          const SizedBox(height: 18),
          _PasswordField(label: 'Confirmar la contraseña', controller: pass2),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '•  Mínimo 8 caracteres.\n'
              '•  Al menos una mayúscula (A-Z) y una minúscula (a-z).\n'
              '•  Al menos un número (0-9).\n'
              '•  Al menos un carácter especial (!@#\$%^&* etc.).',
              style: TextStyle(
                fontSize: 13.2,
                height: 1.4,
                color: Color(0xFF6B667A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          _ActionButtonLike(
            text: 'Continuar',
            bg: const Color(0xFF2F51FF),
            fg: Colors.white,
            trailingArrow: true,
            onTap: onContinue,
          ),
          const SizedBox(height: 12),
          _ActionButtonLike(
            text: 'Atras',
            bg: const Color(0xFFE9EDFF),
            fg: Colors.black87,
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
              Icons.text_fields_rounded,
              color: Color(0xFF200F4C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: widget.label,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarStep extends StatelessWidget {
  const _AvatarStep({
    required this.avatarFile,
    required this.onPick,
    required this.onContinue,
    required this.onBack,
  });

  final File? avatarFile;
  final VoidCallback onPick;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      child: Column(
        children: [
          const _MRLogo(),
          const SizedBox(height: 10),
          const Text(
            'Foto de perfil',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          const Text(
            'Puedes agregar una imagen ahora o hacerlo más tarde.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: Color(0xFF6B667A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onPick,
            child: CircleAvatar(
              radius: 58,
              backgroundColor: const Color.fromARGB(255, 230, 232, 255),
              backgroundImage:
                  avatarFile != null ? FileImage(avatarFile!) : null,
              child:
                  avatarFile == null
                      ? const Icon(
                        Icons.camera_alt_rounded,
                        size: 32,
                        color: Color(0xFF200F4C),
                      )
                      : null,
            ),
          ),
          const Spacer(),
          _ActionButtonLike(
            text: 'Continuar',
            bg: const Color(0xFF2F51FF),
            fg: Colors.white,
            trailingArrow: true,
            onTap: onContinue,
          ),
          const SizedBox(height: 12),
          _ActionButtonLike(
            text: 'Atras',
            bg: const Color(0xFFE9EDFF),
            fg: Colors.black87,
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.onFinish, required this.onBack});

  final VoidCallback onFinish;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      child: Column(
        children: [
          const _MRLogo(),
          const SizedBox(height: 10),
          const Text(
            '¡Todo listo!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tu cuenta ha sido configurada. A partir de ahora\n'
            'podrás levantar tickets, consultar el estado de\n'
            'tus equipos y coordinar con nuestro equipo de\n'
            'soporte desde MR SoS.\n\n'
            'Cuando pulses Finalizar, guardaremos tus\n'
            'cambios y te llevaremos directamente a la\n'
            'plataforma.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: Color(0xFF6B667A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _ActionButtonLike(
            text: 'Finalizar',
            bg: const Color(0xFF2F51FF),
            fg: Colors.white,
            onTap: onFinish,
          ),
          const SizedBox(height: 12),
          _ActionButtonLike(
            text: 'Atras',
            bg: const Color(0xFFE9EDFF),
            fg: Colors.black87,
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

/* ====== Componentes UI ====== */

class _MRLogo extends StatelessWidget {
  const _MRLogo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Image.asset(
        'assets/images/MRlogo.png',
        height: 74,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _IntroScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final String secondaryText;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool showStats;
  final String stat1Label, stat1Value;
  final String stat2Label, stat2Value;
  final String stat3Label, stat3Value;

  const _IntroScreen({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.secondaryText,
    required this.onNext,
    required this.onBack,
    this.showStats = false,
    this.stat1Label = '',
    this.stat1Value = '',
    this.stat2Label = '',
    this.stat2Value = '',
    this.stat3Label = '',
    this.stat3Value = '',
  });

  static const Color mrBlue = Color(0xFF2F51FF);
  static const Color subInk = Color(0xFF6B667A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      child: Column(
        children: [
          const _MRLogo(),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              color: subInk,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showStats) ...[
            const SizedBox(height: 22),
            _StatsRow(
              aLabel: stat1Label,
              aValue: stat1Value,
              bLabel: stat2Label,
              bValue: stat2Value,
              cLabel: stat3Label,
              cValue: stat3Value,
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: mrBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE9EDFF),
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                secondaryText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.aLabel,
    required this.aValue,
    required this.bLabel,
    required this.bValue,
    required this.cLabel,
    required this.cValue,
  });

  final String aLabel, aValue;
  final String bLabel, bValue;
  final String cLabel, cValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(label: aLabel, value: aValue)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: bLabel, value: bValue)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(width: 220, child: _StatCard(label: cLabel, value: cValue)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B667A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

/// ✅ MISMO estilo que _InfoCard del usuario_detail_screen.dart
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailingText,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String trailingText;
  final VoidCallback onTap;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
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
                child: Icon(icon, color: mrPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B667A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value.isEmpty ? '—' : value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B667A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón similar a tus botones del diseño (mismo “pill”)
class _ActionButtonLike extends StatelessWidget {
  const _ActionButtonLike({
    required this.text,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.trailingArrow = false,
  });

  final String text;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (trailingArrow) ...[
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}
