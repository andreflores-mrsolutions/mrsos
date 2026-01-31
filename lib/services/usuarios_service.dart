import 'package:dio/dio.dart';

class UsuariosService {
  UsuariosService({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<Map<String, dynamic>> listado({
    String q = '',
    String rol = '',
    int czId = 0,
    int csId = 0,
    String notif = '',
  }) async {
    final res = await _dio.get(
      '/usuarios_listado.php',
      queryParameters: {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (rol.trim().isNotEmpty) 'rol': rol.trim(),
        if (czId > 0) 'czId': czId,
        if (csId > 0) 'csId': csId,
        if (notif == '0' || notif == '1') 'notif': notif,
      },
    );

    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    return {
      'success': false,
      'error': res.data?.toString() ?? 'Respuesta inválida',
    };
  }
}
