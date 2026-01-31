import 'package:dio/dio.dart';

class ReportesService {
  ReportesService({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<Map<String, dynamic>> listar({
    required String tab, // HS_T | HS_HC | POLIZAS
    String q = '',
    int? csId,
  }) async {
    final res = await _dio.get(
      '/reportes_listar.php',
      queryParameters: {
        'tab': tab,
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (csId != null && csId > 0) 'csId': csId,
      },
    );

    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    return {
      'success': false,
      'error': res.data?.toString() ?? 'Respuesta inválida',
    };
  }
}
