import 'package:dio/dio.dart';
import 'app_http.dart';

class IndexService {
  IndexService({required Dio dio}) : _dio = dio;
  final Dio _dio;
  String _endpoint(String name) =>
      Uri.parse(
        '${_dio.options.baseUrl}/',
      ).resolve('../dashboard/api/$name.php').toString();

  Future<Map<String, dynamic>> tickets() async =>
      AppHttp.jsonMap((await _dio.get(_endpoint('tickets_list'))).data);

  // The gateway exposes health_create, but no Health Check history endpoint.
  // Do not infer an empty agenda from the absence of a published API.
  Future<Map<String, dynamic>> getIndexData() async =>
      throw UnsupportedError(
        'El servidor actual no publica la agenda de Health Check.',
      );

  /// Kept for existing clients; the current web dashboard uses tickets.meta.
  Future<Map<String, dynamic>> estadisticasMes() async => tickets();

  Future<Map<String, dynamic>> obtenerTicketsSedes() async {
    final data = await tickets();
    return groupBySite(data);
  }

  static Map<String, dynamic> groupBySite(Map<String, dynamic> data) {
    final groups = <String, Map<String, dynamic>>{};
    for (final raw in data['tickets'] as List? ?? []) {
      if (raw is! Map) continue;
      final ticket = Map<String, dynamic>.from(raw);
      // tickets_list does not expose csId; do not invent an authorization ID.
      final key =
          '${ticket['clNombre']}|${ticket['czId']}|${ticket['csNombre']}';
      final site = groups.putIfAbsent(
        key,
        () => <String, dynamic>{
          'csId': ticket['csId'],
          'viewKey': key,
          'csNombre': ticket['csNombre'] ?? 'Sin sede',
          'clNombre': ticket['clNombre'],
          'tickets': <Map<String, dynamic>>[],
        },
      );
      (site['tickets'] as List).add(ticket);
    }
    return {...data, 'sedes': groups.values.toList()};
  }

  Future<Map<String, dynamic>> detalleTicket({required int tiId}) async =>
      AppHttp.jsonMap(
        (await _dio.get(
          _endpoint('ticket_detail'),
          queryParameters: {'tiId': tiId},
        )).data,
      );
}
