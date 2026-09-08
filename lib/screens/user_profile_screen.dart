import 'dart:io';
// ignore: unused_import
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mrsos/screens/login_screen.dart';
import 'package:mrsos/services/app_http.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../config/app_config.dart';
import '../services/document_service.dart';
import 'package:mrsos/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';
import '../widget/mr_skeleton.dart';
import '../widget/colors.dart';
import '../widget/mr_theme.dart';
import '../widget/mr_components.dart';
import 'change_password_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.baseUrl, // ej: http://192.168.3.7/php  (mismo host)
  });

  final String baseUrl;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  late final ProfileService _profile;

  bool _loading = true;
  bool prefBiometricos = false;
  final LocalAuthentication _auth = LocalAuthentication();

  // Datos en memoria (editables)

  String usId = '';
  String usNombre = '';
  String usAPaterno = '';
  String usAMaterno = '';
  String usCorreo = '';
  String usTelefono = '';
  String usUsername = '';
  String usImagen = '';
  File? _localAvatar;

  // Preferencias (por ahora UI; si quieres las guardamos en SharedPreferences)
  bool prefNotificaciones = true;
  bool prefCorreos = true;
  NotificationPreferences? _preferences;
  bool _savingPreferences = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAndValidateBiometrics();
    // IMPORTANTE: inicializar el service (antes de cualquier _saveProfile)
    _profile = ProfileService(dio: AppHttp.I.dio);

    _loadProfile();
  }

  Future<void> _loadPreferences() async {
    try {
      final value =
          await NotificationsService(dio: AppHttp.I.dio).loadPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = value;
        prefNotificaciones = value.inApp;
        prefCorreos = value.mail;
      });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppHttp.friendlyError(error)),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _loadPreferences,
            ),
          ),
        );
    }
  }

  Future<void> _savePreferences(NotificationPreferences value) async {
    if (_savingPreferences || _preferences == null) return;
    setState(() => _savingPreferences = true);
    try {
      await NotificationsService(dio: AppHttp.I.dio).savePreferences(value);
      if (!mounted) return;
      setState(() {
        _preferences = value;
        prefNotificaciones = value.inApp;
        prefCorreos = value.mail;
      });
      await PushService.I.sync(requestPermission: value.inApp);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppHttp.friendlyError(error))));
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  Future<void> _onToggleNotificaciones(bool enabled) async {
    if (_preferences != null)
      await _savePreferences(_preferences!.copyWith(inApp: enabled));
  }

  Future<void> _onToggleCorreos(bool enabled) async {
    if (_preferences != null)
      await _savePreferences(_preferences!.copyWith(mail: enabled));
  }

  Future<void> _signOut() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await PushService.I.signOut();
      await AppHttp.I.dio.get('/logout.php', queryParameters: {'ajax': 1});
      await AppHttp.I.clearSession();
      await DocumentService.clearCache();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeLoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo cerrar la sesión de forma segura. ${AppHttp.friendlyError(error)}',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAndValidateBiometrics() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getBool('pref_bio') ?? false;

    // Checamos soporte real del dispositivo
    final supported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;

    // Si estaba activado pero YA NO hay soporte/permiso -> apagar y guardar
    if (saved && !(supported && canCheck)) {
      await sp.setBool('pref_bio', false);
      setState(() => prefBiometricos = false);
      return;
    }

    setState(() => prefBiometricos = saved);
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    final p = await SessionStore().getProfile();
    print('=== MIS DATOS: PROFILE FROM STORE ===');
    print(p);
    print('====================================');

    if (!mounted) return;
    setState(() {
      usId = (p['usId'] ?? '').toString();
      usNombre = (p['usNombre'] ?? '').toString();
      usAPaterno = (p['usAPaterno'] ?? '').toString();
      usAMaterno = (p['usAMaterno'] ?? '').toString();
      usCorreo = (p['usCorreo'] ?? '').toString();
      usTelefono = (p['usTelefono'] ?? '').toString();
      usUsername = (p['usUsername'] ?? '').toString();
      usImagen = (p['usImagen'] ?? '').toString();
      _loading = false;
    });
  }

  String get fullName => '$usNombre $usAPaterno $usAMaterno'.trim();

  // ✅ server base (sin /php)
  String get _serverBase => widget.baseUrl.replaceAll('/php', '');

  String? get avatarUrl => AppConfig.avatarUrl(usImagen, username: usUsername);
  String get brandFallbackAvatarByUsername => AppConfig.avatarUrl('0');

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() => _localAvatar = File(x.path));

    // opcional: guardar en cuanto elige
    await _saveProfile();
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      MultipartFile? avatar;
      if (_localAvatar != null) {
        avatar = await MultipartFile.fromFile(
          _localAvatar!.path,
          filename: _localAvatar!.path.split('/').last,
        );
      }

      final res = await _profile.actualizarPerfil(
        usId: usId,
        usNombre: usNombre,
        usAPaterno: usAPaterno,
        usAMaterno: usAMaterno,
        usCorreo: usCorreo,
        usTelefono: usTelefono,
        usUsername: usUsername,
        avatar: avatar,
      );

      if (!mounted) return;

      if (res['success'] == true || res['error'] == '{"success": true}') {
        // Si subiste avatar y tu backend lo guarda como <usUsername>.<ext>
        // y no te regresa filename, lo reconstruimos (mejor esfuerzo).
        if (_localAvatar != null) {
          final ext = _localAvatar!.path.split('.').last.toLowerCase();
          setState(() {
            usImagen = '$usUsername.$ext';
          });
        }

        // ✅ opcional: refrescar desde store si tu backend también actualiza sesión/valores
        await AppHttp.I.refreshSession();
        await _loadProfile();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Datos actualizados',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final msg =
            (res['error'] ?? res['message'] ?? 'No se pudo actualizar')
                .toString();
        print('=== ERROR actualizarPerfil: $msg ===');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Color.fromARGB(255, 175, 76, 76),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('=== ERROR actualizarPerfil: $e ===');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEditNameSheet() {
    final cNombre = TextEditingController(text: usNombre);
    final cApPat = TextEditingController(text: usAPaterno);
    final cApMat = TextEditingController(text: usAMaterno);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SheetContainer(
          title: 'Cambiar datos',
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InputRow(
                  icon: Icons.person_rounded,
                  label: 'Nombre',
                  controller: cNombre,
                ),
                const SizedBox(height: 10),
                _InputRow(
                  icon: Icons.badge_rounded,
                  label: 'Apellido Paterno',
                  controller: cApPat,
                ),
                const SizedBox(height: 10),
                _InputRow(
                  icon: Icons.badge_outlined,
                  label: 'Apellido Materno',
                  controller: cApMat,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mrPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed:
                        _loading
                            ? null
                            : () async {
                              setState(() {
                                usNombre = cNombre.text.trim();
                                usAPaterno = cApPat.text.trim();
                                usAMaterno = cApMat.text.trim();
                              });
                              Navigator.pop(context);
                              await _saveProfile();
                            },
                    child: const Text(
                      'Cambiar datos',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEditFieldSheet({
    required String title,
    required IconData icon,
    required String initial,
    required void Function(String v) apply,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final c = TextEditingController(text: initial);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SheetContainer(
          title: title,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InputRow(
                  icon: icon,
                  label: title,
                  controller: c,
                  keyboardType: keyboardType,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mrPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed:
                        _loading
                            ? null
                            : () async {
                              setState(() => apply(c.text.trim()));
                              Navigator.pop(context);
                              await _saveProfile();
                            },
                    child: const Text(
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPasswordWeb() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
  }

  ImageProvider<Object>? _avatarProvider() {
    if (_localAvatar != null) return FileImage(_localAvatar!);
    final url =
        avatarUrl ??
        (usUsername.isNotEmpty ? brandFallbackAvatarByUsername : null);
    if (url == null) return null;
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MRSColors.bg,
      appBar: AppBar(
        backgroundColor: MRSColors.bg,
        title: const Text(
          'Cuenta y ajustes',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              const MRPageIntro(
                eyebrow: 'Tu espacio personal',
                title: 'Mi cuenta',
                subtitle:
                    'Tus datos, tu acceso y tus preferencias de servicio.',
              ),
              const SizedBox(height: 24),
              MRSectionCard(
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Cambiar fotografía de perfil',
                      child: InkWell(
                        onTap: _loading ? null : _pickAvatar,
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: MRSColors.blueSoft,
                              foregroundImage: _avatarProvider(),
                              onForegroundImageError:
                                  _avatarProvider() == null ? null : (_, _) {},
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 32,
                                color: MRSColors.accent,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: MRSColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MRSkeleton(
                        enabled: _loading,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'MR Support One Service',
                              style: TextStyle(
                                color: MRSColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const MRSectionHeading(
                title: 'Información personal',
                subtitle: 'Mantén tus datos de contacto actualizados',
              ),

              _ProfileTile(
                icon: Icons.person_rounded,
                label: 'Nombre completo',
                value: fullName,
                onEdit: _loading ? () {} : _openEditNameSheet,
              ),
              const SizedBox(height: 20),

              _ProfileTile(
                icon: Icons.phone_rounded,
                label: 'Número de contacto',
                value: usTelefono,
                onEdit:
                    _loading
                        ? () {}
                        : () => _openEditFieldSheet(
                          title: 'Número de contacto',
                          icon: Icons.phone_rounded,
                          initial: usTelefono,
                          keyboardType: TextInputType.phone,
                          apply: (v) => usTelefono = v,
                        ),
              ),
              const SizedBox(height: 20),

              _ProfileTile(
                icon: Icons.mail_rounded,
                label: 'Correo electrónico',
                value: usCorreo,
                onEdit:
                    _loading
                        ? () {}
                        : () => _openEditFieldSheet(
                          title: 'Correo Electrónico',
                          icon: Icons.mail_rounded,
                          initial: usCorreo,
                          keyboardType: TextInputType.emailAddress,
                          apply: (v) => usCorreo = v,
                        ),
              ),
              const SizedBox(height: 20),

              _ProfileTile(
                icon: Icons.alternate_email_rounded,
                label: 'Usuario',
                value: usUsername,
                onEdit:
                    _loading
                        ? () {}
                        : () => _openEditFieldSheet(
                          title: 'Usuario',
                          icon: Icons.alternate_email_rounded,
                          initial: usUsername,
                          apply: (v) => usUsername = v,
                        ),
              ),

              const SizedBox(height: 20),

              // Cambiar contraseña
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MRSColors.blueSoft,
                    foregroundColor: MRSColors.accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _openPasswordWeb,
                  child: const Text(
                    'Cambiar contraseña',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Preferencias
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MRSColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MRSColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seguridad y avisos',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    if (_preferences == null)
                      const Text('Consultando preferencias compartidas…'),
                    if (_savingPreferences) const LinearProgressIndicator(),
                    _SwitchRow(
                      label: 'Notificaciones',
                      value: prefNotificaciones,
                      onChanged: _onToggleNotificaciones,
                    ),
                    _SwitchRow(
                      label: 'Correos',
                      value: prefCorreos,
                      onChanged: _onToggleCorreos,
                    ),
                    if (_preferences != null) ...[
                      _SwitchRow(
                        label: 'Cambios de ticket',
                        value: _preferences!.ticketChanges,
                        onChanged:
                            (v) => _savePreferences(
                              _preferences!.copyWith(ticketChanges: v),
                            ),
                      ),
                      _SwitchRow(
                        label: 'Reuniones',
                        value: _preferences!.meet,
                        onChanged:
                            (v) => _savePreferences(
                              _preferences!.copyWith(meet: v),
                            ),
                      ),
                      _SwitchRow(
                        label: 'Visitas',
                        value: _preferences!.visit,
                        onChanged:
                            (v) => _savePreferences(
                              _preferences!.copyWith(visit: v),
                            ),
                      ),
                      _SwitchRow(
                        label: 'Folios de acceso',
                        value: _preferences!.folio,
                        onChanged:
                            (v) => _savePreferences(
                              _preferences!.copyWith(folio: v),
                            ),
                      ),
                    ],
                    _SwitchRow(
                      label: 'Acceso biométrico',
                      value: prefBiometricos,
                      onChanged: (v) async {
                        final sp = await SharedPreferences.getInstance();

                        // Si quiere ACTIVAR biometría
                        if (v) {
                          final supported = await _auth.isDeviceSupported();
                          final canCheck = await _auth.canCheckBiometrics;

                          // No hay soporte real -> no permitir
                          if (!(supported && canCheck)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Este dispositivo no soporta biometría o no tiene permisos',
                                ),
                              ),
                            );
                            return;
                          }

                          // Validación real (una sola vez)
                          bool ok = false;
                          try {
                            ok = await _auth.authenticate(
                              localizedReason:
                                  'Confirma tu identidad para activar biometría',
                              options: const AuthenticationOptions(
                                biometricOnly: false,
                                stickyAuth: true,
                              ),
                            );
                          } catch (_) {
                            ok = false;
                          }

                          if (!ok) return;
                        }

                        // Guardar preferencia final
                        await sp.setBool('pref_bio', v);
                        setState(() => prefBiometricos = v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cerrar sesión
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE7EC),
                    foregroundColor: const Color(0xFFB3261E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _loading ? null : _signOut,
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: MRSColors.border),
    ),
    child: InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            MRIconBox(icon: icon, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
                  const SizedBox(height: 5),
                  Text(
                    value.isEmpty ? 'Sin registrar' : value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.edit_outlined, color: MRSColors.accent, size: 19),
          ],
        ),
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SheetContainer extends StatelessWidget {
  const _SheetContainer({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  static const mrPurple = Color.fromARGB(255, 10, 7, 58);

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: mrPurple, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
