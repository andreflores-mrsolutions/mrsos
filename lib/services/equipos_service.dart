import 'package:dio/dio.dart';
import 'app_http.dart';

class EquiposService {
  EquiposService({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<Map<String, dynamic>> resumen() async {
    final res = await _dio.get('/mis_equipos_resumen.php');
    final data = AppHttp.jsonMap(res.data);
    final policies =
        (data['polizas'] as List? ?? [])
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
    // resumen.equipos is only a preview (LIMIT 6), not a total.
    for (var offset = 0; offset < policies.length; offset += 3) {
      await Future.wait(
        policies.skip(offset).take(3).map((policy) async {
          final detail = await porPoliza(pcId: int.parse('${policy['pcId']}'));
          policy['total_equipos'] =
              detail['total_equipos'] ??
              (detail['equipos'] as List? ?? []).length;
        }),
      );
    }
    return {...data, 'polizas': policies};
  }

  static bool isActivePolicy(Map<String, dynamic> p, {DateTime? now}) {
    final status =
        '${p['pcEstatus'] ?? p['pcEstado'] ?? ''}'.trim().toLowerCase();
    if (['inactivo', 'error', 'vencida', 'vencido', 'cambios'].contains(status))
      return false;
    final today = now ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final end = DateTime.tryParse('${p['pcFechaFin'] ?? ''}');
    final start = DateTime.tryParse('${p['pcFechaInicio'] ?? ''}');
    if (end != null && end.isBefore(day)) return false;
    if (start != null && start.isAfter(day)) return false;
    if (status == 'activo') return true;
    final flag = p['vigente'] ?? p['pcVigente'];
    return flag == true || flag == 1 || flag == '1';
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

  Future<Map<String, dynamic>> detalleEquipo({
    required int peId,
    required int pcId,
  }) async {
    // Use the server-scoped policy catalog. The old detail route is not public.
    final catalog = await porPoliza(pcId: pcId);
    final matches =
        (catalog['equipos'] as List? ?? [])
            .whereType<Map>()
            .where((e) => int.tryParse('${e['peId']}') == peId)
            .toList();
    if (matches.isEmpty)
      throw StateError('Equipo fuera del catálogo de tus sedes.');
    return {
      'success': true,
      'equipo': Map<String, dynamic>.from(matches.single),
      'ticketsAvailable': false,
      'disclaimer':
          'El catálogo actual no publica especificaciones avanzadas ni historial por equipo. Consulta los casos en Tickets.',
      'prefix': catalog['prefix'] ?? 'TKT',
    };
  }
}
