import 'dart:convert';

import 'package:dio/dio.dart';

class ProfileService {
  ProfileService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// POST /actualizar_perfil.php
  /// Requiere sesión PHP activa (cookies).
  Future<Map<String, dynamic>> actualizarPerfil({
    required String usId,
    required String usNombre,
    required String usAPaterno,
    required String usAMaterno,
    required String usCorreo,
    required String usTelefono,
    required String usUsername,
    MultipartFile? avatar, // opcional: usAvatar
  }) async {
    final form = FormData.fromMap({
      'usId': usId.trim(),
      'usNombre': usNombre.trim(),
      'usAPaterno': usAPaterno.trim(),
      'usAMaterno': usAMaterno.trim(),
      'usCorreo': usCorreo.trim(),
      'usTelefono': usTelefono.trim(),
      'usUsername': usUsername.trim(),
      if (avatar != null) 'usAvatar': avatar,
    });

    final res = await _dio.post('/actualizar_perfil.php', data: form);

    // El PHP devuelve JSON success:true al final
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    final decoded = jsonDecode(res.data.toString());
    if (decoded is Map) return Map<String, dynamic>.from(decoded);

    // fallback
    return {
      'success': false,
      'error': res.data?.toString() ?? 'Respuesta inválida',
    };
  }
}
