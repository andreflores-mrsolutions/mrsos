import 'package:dio/dio.dart';
import 'app_http.dart';
import 'profile_service.dart';

class OnboardingSaveResult {
  const OnboardingSaveResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class OnboardingService {
  OnboardingService({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<OnboardingSaveResult> save({
    required int usId,
    required String usNombre,
    required String usAPaterno,
    required String usAMaterno,
    required String usCorreo,
    required String usTelefono,
    required String usUsername,
    String pass1 = '',
    String pass2 = '',
    MultipartFile? avatar,
  }) async {
    // Check the server on every explicit retry. A previous password update may
    // have succeeded even if the following profile update failed.
    final session = AppHttp.jsonMap((await _dio.get('/me.php')).data);
    if (int.tryParse('${session['usId']}') != usId) {
      throw StateError('La sesión cambió. Inicia sesión nuevamente.');
    }
    if (session['forceChangePass'] == true) {
      if (pass1 != pass2 ||
          pass1.length < 10 ||
          !RegExp(r'[A-Za-z]').hasMatch(pass1) ||
          !RegExp(r'\d').hasMatch(pass1)) {
        throw StateError(
          'Usa al menos 10 caracteres e incluye letras y números.',
        );
      }
      await _dio.post(
        '/usuario_password_primera_vez.php',
        data: {'password': pass1, 'password2': pass2},
      );
      // Remember-me/password changes can renew the session/CSRF token.
      await _dio.get('/me.php');
    }
    final result = await ProfileService(dio: _dio).actualizarPerfil(
      usId: '$usId',
      usNombre: usNombre,
      usAPaterno: usAPaterno,
      usAMaterno: usAMaterno,
      usCorreo: usCorreo,
      usTelefono: usTelefono,
      usUsername: usUsername,
      avatar: avatar,
    );
    if (result['success'] != true) throw StateError(AppHttp.message(result));
    return const OnboardingSaveResult(
      success: true,
      message: 'Perfil actualizado.',
    );
  }
}
