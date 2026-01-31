import 'package:dio/dio.dart';

class IndexService {
  IndexService({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<Map<String, dynamic>> getIndexData() async {
    final r = await _dio.get('/getIndexData.php');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> estadisticasMes() async {
    final r = await _dio.get('/estadisticas_mes.php');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> obtenerTicketsSedes() async {
    final r = await _dio.get('/obtener_tickets_sedes.php');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> detalleTicket({required int tiId}) async {
    final res = await _dio.get(
      '/detalle_ticket.php',
      queryParameters: {'tiId': tiId},
    );
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    throw Exception('Respuesta inválida detalle_ticket');
  }
}
