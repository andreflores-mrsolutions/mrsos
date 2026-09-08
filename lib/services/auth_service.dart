import 'package:dio/dio.dart';
import 'app_http.dart';

class LoginResult {
  final bool success;
  final String message;
  final bool forceChangePass;
  final bool onboardingRequired;
  final Map<String, dynamic>? user;

  LoginResult({
    required this.success,
    required this.message,
    required this.forceChangePass,
    required this.onboardingRequired,
    this.user,
  });

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
    success: j['success'] == true,
    message: (j['message'] ?? '').toString(),
    forceChangePass: j['forceChangePass'] == true,
    onboardingRequired: j['onboardingRequired'] == true,
    user: (j['user'] is Map) ? Map<String, dynamic>.from(j['user']) : null,
  );
}

class AuthService {
  final Dio _dio;
  final String loginPath;

  AuthService({required Dio dio, required this.loginPath}) : _dio = dio;

  Future<LoginResult> login({
    required String usId,
    required String usPass,
  }) async {
    final res = await _dio.post(
      loginPath,
      data: FormData.fromMap({
        'usId': usId.trim(),
        'usPass': usPass,
        'remember': '1',
      }),
    );

    final result = AppHttp.jsonMap(res.data);
    if (result['success'] != true) return LoginResult.fromJson(result);
    final me = AppHttp.jsonMap((await _dio.get('/me.php')).data);
    if (me['success'] != true || me['usId'] == null) {
      throw StateError('No se pudo recuperar la sesión del servidor.');
    }
    return LoginResult.fromJson({
      ...result,
      'user': me,
      'forceChangePass':
          result['forceChangePass'] == true || me['forceChangePass'] == true,
      'onboardingRequired':
          result['onboardingRequired'] == true ||
          '${me['usConfirmado']}'.toLowerCase() == 'no',
    });
  }
}
