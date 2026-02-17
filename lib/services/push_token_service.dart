import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class PushTokenSaveResult {
  final bool success;
  final String message;

  PushTokenSaveResult({required this.success, required this.message});

  factory PushTokenSaveResult.fromJson(Map<String, dynamic> j) =>
      PushTokenSaveResult(
        success: j['success'] == true || j['ok'] == true,
        message: (j['message'] ?? j['msg'] ?? '').toString(),
      );
}

class PushTokenService {
  final Dio _dio;
  final String savePath; // ej: /notif_token_guardar.php

  PushTokenService({required Dio dio, required this.savePath}) : _dio = dio;

  Future<PushTokenSaveResult> saveToken({
    required String token,
    required String platform, // android / ios / web
    String? deviceId,
  }) async {
    final res = await _dio.post(
      savePath,
      data: FormData.fromMap({
        'platform': platform,
        'token': token,
        'deviceId': deviceId,
      }),
    );
    debugPrint('SEND deviceId=$deviceId tokenLen=${token.length}');

    if (res.data is Map) {
      return PushTokenSaveResult.fromJson(Map<String, dynamic>.from(res.data));
    }
    final decoded = json.decode(res.data.toString());
    return PushTokenSaveResult.fromJson(Map<String, dynamic>.from(decoded));
  }
}
