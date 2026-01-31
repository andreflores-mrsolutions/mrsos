import 'package:dio/dio.dart';

class EquiposService {
  EquiposService({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<Map<String, dynamic>> resumen() async {
    final res = await _dio.get('/mis_equipos_resumen.php');
    print(res);
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    throw Exception('Respuesta inválida (resumen)');
  }

  Future<Map<String, dynamic>> porPoliza({
    required int pcId,
    int? csId,
    String tipo = '',
    String q = '',
  }) async {
    final res = await _dio.get(
      '/mis_equipos_poliza.php',
      queryParameters: {
        'pcId': pcId,
        if (csId != null && csId > 0) 'csId': csId,
        if (tipo.isNotEmpty) 'tipo': tipo,
        if (q.isNotEmpty) 'q': q,
      },
    );
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    throw Exception('Respuesta inválida (porPoliza)');
  }

  Future<Map<String, dynamic>> detalleEquipo({required int peId}) async {
    final res = await _dio.get(
      '/equipo_detalle.php',
      queryParameters: {'peId': peId},
    );
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    throw Exception('Respuesta inválida (detalleEquipo)');
  }
}
