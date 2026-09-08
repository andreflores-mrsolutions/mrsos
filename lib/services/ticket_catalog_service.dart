import 'package:dio/dio.dart';
import 'app_http.dart';

class TicketCatalogService {
  TicketCatalogService(this.dio);
  final Dio dio;
  String endpoint(String name) =>
      Uri.parse(
        '${dio.options.baseUrl}/',
      ).resolve('../dashboard/api/$name.php').toString();

  Future<List<Map<String, dynamic>>> sites({bool healthOnly = false}) async {
    final data = AppHttp.jsonMap(
      (await dio.get(endpoint('ticket_catalog_sedes'))).data,
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
  }) async {
    final data = AppHttp.jsonMap(
      (await dio.get(
        endpoint('ticket_catalog_equipos'),
        queryParameters: {'csId': csId},
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
}
