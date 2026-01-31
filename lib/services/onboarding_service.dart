import 'dart:convert';
import 'package:dio/dio.dart';

class OnboardingSaveResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? user;

  OnboardingSaveResult({
    required this.success,
    required this.message,
    this.user,
  });

  factory OnboardingSaveResult.fromJson(Map<String, dynamic> j) =>
      OnboardingSaveResult(
        success: j['success'] == true,
        message: (j['message'] ?? '').toString(),
        user: (j['user'] is Map) ? Map<String, dynamic>.from(j['user']) : null,
      );
}

class OnboardingService {
  final Dio _dio;
  final String savePath; // /guardar_onboarding.php

  OnboardingService({required Dio dio, required this.savePath}) : _dio = dio;

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
  }) async {
    final res = await _dio.post(
      savePath,
      data: FormData.fromMap({
        'usId': usId,
        'usNombre': usNombre.trim(),
        'usAPaterno': usAPaterno.trim(),
        'usAMaterno': usAMaterno.trim(),
        'usCorreo': usCorreo.trim(),
        'usTelefono': usTelefono.trim(),
        'usUsername': usUsername.trim(),
        'pass1': pass1,
        'pass2': pass2,
      }),
    );

    if (res.data is Map) {
      return OnboardingSaveResult.fromJson(Map<String, dynamic>.from(res.data));
    }
    final decoded = json.decode(res.data.toString());
    return OnboardingSaveResult.fromJson(Map<String, dynamic>.from(decoded));
  }
}
