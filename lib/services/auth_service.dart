import 'package:dio/dio.dart';
import 'app_http.dart';

class LoginResult {
  final bool success;
  final String message;
  final bool forceChangePass;
  final bool onboardingRequired;
  final bool mfaRequired;
  final String emailHint;
  final int expiresIn;
  final Map<String, dynamic>? user;

  LoginResult({
    required this.success,
    required this.message,
    required this.forceChangePass,
    required this.onboardingRequired,
    this.mfaRequired = false,
    this.emailHint = '',
    this.expiresIn = 0,
    this.user,
  });

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
    success: j['success'] == true,
    message: (j['message'] ?? '').toString(),
    forceChangePass: j['forceChangePass'] == true,
    onboardingRequired: j['onboardingRequired'] == true,
    mfaRequired: j['mfaRequired'] == true,
    emailHint: (j['emailHint'] ?? '').toString(),
    expiresIn: int.tryParse('${j['expiresIn']}') ?? 0,
    user: j['user'] is Map ? Map<String, dynamic>.from(j['user']) : null,
  );
}

class AuthService {
  final Dio _dio;
  final String loginPath;
  String? _challengeCsrf;
  DateTime? _expiresAt;

  AuthService({required Dio dio, required this.loginPath}) : _dio = dio;

  Future<LoginResult> login({
    required String usId,
    required String usPass,
    bool remember = false,
  }) async {
    _challengeCsrf = null;
    _expiresAt = null;
    final res = await _dio.post(
      loginPath,
      data: FormData.fromMap({
        'usId': usId.trim(),
        'usPass': usPass,
        'remember': remember ? '1' : '0',
      }),
    );
    final result = AppHttp.jsonMap(res.data);
    final login = LoginResult.fromJson(result);
    if (!login.success) return login;
    if (login.mfaRequired) {
      final token = result['csrfToken']?.toString();
      if (token == null || token.isEmpty || login.expiresIn <= 0) {
        throw StateError('El servidor no entregó un desafío válido.');
      }
      _challengeCsrf = token;
      _expiresAt = DateTime.now().add(Duration(seconds: login.expiresIn));
      // The pending PHP session is NOT an authenticated user session.
      return login;
    }
    return _authenticated(result);
  }

  Future<LoginResult> verify(String code) async {
    if (_challengeCsrf == null ||
        _expiresAt == null ||
        !DateTime.now().isBefore(_expiresAt!)) {
      throw StateError(
        'El código expiró. Vuelve a iniciar sesión para recibir otro.',
      );
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw StateError('Escribe el código de seis dígitos.');
    }
    final response = await _dio.post(
      loginPath,
      data: FormData.fromMap({'action': 'verify', 'code': code.trim()}),
      options: Options(
        headers: {'X-CSRF-Token': _challengeCsrf},
        extra: {'mrsMfaVerify': true},
      ),
    );
    final result = AppHttp.jsonMap(response.data);
    if (result['success'] != true) return LoginResult.fromJson(result);
    if (result['mfaRequired'] == true) {
      throw StateError('La verificación no se completó.');
    }
    _challengeCsrf = null;
    _expiresAt = null;
    // Verification consumed the one-time code. The access gate owns retriable
    // GET /me.php checks so a failed read never resubmits a consumed code.
    return LoginResult.fromJson(result);
  }

  Future<LoginResult> _authenticated(Map<String, dynamic> result) async {
    final me = AppHttp.jsonMap((await _dio.get('/me.php')).data);
    if (me['success'] != true || me['usId'] == null) {
      throw StateError('No se pudo recuperar la sesión del servidor.');
    }
    return LoginResult.fromJson({
      ...result,
      'user': me,
      'forceChangePass':
          result['forceChangePass'] == true || me['forceChangePass'] == true,
    });
  }
}
