import 'package:dio/dio.dart';
import 'app_http.dart';

/// Adapts the current web responses; no PHP or database changes are required.
class ReportesService {
  ReportesService({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<Map<String, dynamic>> listar({
    required String tab,
    String q = '',
    int? csId,
  }) async {
    final query = q.trim().toLowerCase();
    if (tab == 'POLIZAS') {
      final json = AppHttp.jsonMap(
        (await _dio.get('/mis_equipos_resumen.php')).data,
      );
      final documents = <Map<String, dynamic>>[];
      for (final p in (json['polizas'] as List? ?? []).whereType<Map>()) {
        if (query.isNotEmpty &&
            !'${p['pcIdentificador']} ${p['pcTipoPoliza']}'
                .toLowerCase()
                .contains(query))
          continue;
        final links = p['documents'];
        if (links is! Map) continue;
        for (final type in ['poliza', 'wk', 'factura']) {
          if (links[type] == null || '${links[type]}'.isEmpty) continue;
          documents.add({
            ...Map<String, dynamic>.from(p),
            'pcIdentificador':
                '${p['pcIdentificador'] ?? 'Póliza'} · ${type.toUpperCase()}',
            'url': links[type],
          });
        }
      }
      return {'success': true, 'count': documents.length, 'polizas': documents};
    }
    // The web returns at most 500 sheets and does not expose a reliable HS type
    // or csId. Keep a single sheet list; never invent a server-side site scope.
    final endpoint =
        Uri.parse(
          '${_dio.options.baseUrl}/',
        ).resolve('../backend/admin/api/hoja_servicio_list.php').toString();
    final data = AppHttp.jsonMap((await _dio.get(endpoint)).data);
    final groups = <String, Map<String, dynamic>>{};
    var count = 0;
    for (final row in (data['hojas'] as List? ?? []).whereType<Map>()) {
      final item = Map<String, dynamic>.from(row);
      final searchable =
          [
            'hsFolio',
            'clNombre',
            'csNombre',
            'eqModelo',
            'maNombre',
            'peSN',
          ].map((key) => '${item[key] ?? ''}').join(' ').toLowerCase();
      if (query.isNotEmpty && !searchable.contains(query)) continue;
      final id = int.tryParse('${item['hsId']}') ?? 0;
      if (id <= 0) continue;
      final groupKey = '${item['clId']}|${item['csNombre']}';
      final group = groups.putIfAbsent(
        groupKey,
        () => {
          'csNombre': [
            item['clNombre'],
            item['csNombre'],
          ].where((v) => v != null && '$v'.trim().isNotEmpty).join(' · '),
          'items': <Map<String, dynamic>>[],
        },
      );
      (group['items'] as List).add({
        ...item,
        'folio': item['hsFolio'] ?? 'HS-$id',
        'equipo': [
          item['maNombre'],
          item['eqModelo'],
          item['peSN'],
        ].where((v) => v != null && '$v'.trim().isNotEmpty).join(' · '),
        'url': 'backend/admin/api/hoja_servicio_download.php?hsId=$id',
      });
      count++;
    }
    return {'success': true, 'count': count, 'sedes': groups.values.toList()};
  }
}
