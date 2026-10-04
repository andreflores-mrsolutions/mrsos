import 'package:dio/dio.dart';
import 'app_http.dart';

class TicketCatalogService {
  TicketCatalogService(this.dio);
  final Dio dio;
  String endpoint(String name, {bool internal = false}) =>
      Uri.parse('${dio.options.baseUrl}/')
          .resolve('../${internal ? 'backend' : 'dashboard'}/api/$name.php')
          .toString();

  Future<List<Map<String, dynamic>>> sites({
    bool healthOnly = false,
    int? clientId,
  }) async {
    final data = AppHttp.jsonMap(
      (await dio.get(
        endpoint('ticket_catalog_sedes', internal: clientId != null),
        queryParameters: {if (clientId != null) 'clId': clientId},
      )).data,
    );
    return (data['sedes'] as List? ?? [])
        .whereType<Map>()
        .map((site) {
          return <String, dynamic>{
            ...Map<String, dynamic>.from(site),
            'csId': int.tryParse('${site['csId']}') ?? 0,
          };
        })
        .where((site) => !healthOnly || site['healthCheckAvailable'] == true)
        .toList();
  }

  Future<List<Map<String, dynamic>>> equipment(
    int csId, {
    bool healthOnly = false,
    int? clientId,
  }) async {
    final data = AppHttp.jsonMap(
      (await dio.get(
        endpoint('ticket_catalog_equipos', internal: clientId != null),
        queryParameters: {'csId': csId, if (clientId != null) 'clId': clientId},
      )).data,
    );
    return (data['equipos'] as List? ?? [])
        .whereType<Map>()
        .where((e) => !healthOnly || e['healthCheckAvailable'] == true)
        .map(
          (e) => <String, dynamic>{
            ...Map<String, dynamic>.from(e),
            'csId': csId,
            'eqModelo': e['modelo'],
            'eqTipoEquipo': e['tipoEquipo'],
            'maNombre': e['marca'],
            'peSN': e['sn'],
            'eqImgPath': e['img'],
            'pcTipoPoliza': e['polizaTipo'],
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> clients() async {
    final data = AppHttp.jsonMap(
      (await dio.get(
        endpoint('clientes/cliente_list', internal: true),
        queryParameters: {'estatus': 'Activo'},
      )).data,
    );
    return (data['clientes'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> responsibleUsers(
    int clientId,
    int siteId,
  ) async {
    final data = AppHttp.jsonMap(
      (await dio.get(
        endpoint('ticket_catalog_clientes', internal: true),
        queryParameters: {'clId': clientId, 'csId': siteId},
      )).data,
    );
    return (data['clientes'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
