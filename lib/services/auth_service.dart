import 'dart:convert';
import 'package:dio/dio.dart';

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
      data: FormData.fromMap({'usId': usId.trim(), 'usPass': usPass}),
    );

    if (res.data is Map) {
      return LoginResult.fromJson(Map<String, dynamic>.from(res.data));
    }

    final decoded = json.decode(res.data.toString());
    return LoginResult.fromJson(Map<String, dynamic>.from(decoded));
  }
}
