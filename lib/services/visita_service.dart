import 'dart:io';
import 'package:dio/dio.dart';
import 'app_http.dart';

class VisitaService {
  VisitaService._();
  static final I = VisitaService._();

  Dio get _dio => AppHttp.I.dio;

  Future<void> proponer({
    required int tiId,
    required DateTime inicio,
    required DateTime fin,
    required int duracionMin,
    required bool requiereAcceso,
    String extraAcceso = '',
  }) async {
    final fecha = _fmtDate(inicio);
    final hora = _fmtTime(
      inicio,
    ); // backend solo recibe una hora; por ahora guardamos inicio
    final form = FormData.fromMap({
      'tiId': tiId,
      'accion': 'proponer',
      'quien': 'CLIENTE',
      'fecha': fecha,
      'hora': hora,
      'duracionMin': duracionMin,
      'requiereAcceso': requiereAcceso ? 1 : 0,
      'extraAcceso': extraAcceso,
    });

    final r = await _dio.post('/visita_actualizar.php', data: form);
    _ensureOk(r.data);
  }

  Future<void> asignar({
    required int tiId,
    required DateTime fechaHora,
    required int duracionMin,
    required bool requiereAcceso,
    String extraAcceso = '',
  }) async {
    final form = FormData.fromMap({
      'tiId': tiId,
      'accion': 'asignar',
      'quien': 'CLIENTE',
      'fecha': _fmtDate(fechaHora),
      'hora': _fmtTime(fechaHora),
      'duracionMin': duracionMin,
      'requiereAcceso': requiereAcceso ? 1 : 0,
      'extraAcceso': extraAcceso,
    });

    final r = await _dio.post('/visita_actualizar.php', data: form);
    _ensureOk(r.data);
  }

  Future<void> cancelar({required int tiId, String motivo = ''}) async {
    final form = FormData.fromMap({
      'tiId': tiId,
      'accion': 'cancelar',
      'motivo': motivo,
    });

    final r = await _dio.post('/visita_actualizar.php', data: form);
    _ensureOk(r.data);
  }

  Future<void> guardarFolio({
    required int tiId,
    required String folio,
    String coment = '',
    File? archivo,
  }) async {
    final map = <String, dynamic>{
      'tiId': tiId,
      'folio': folio,
      'coment': coment,
    };

    if (archivo != null) {
      map['archivo'] = await MultipartFile.fromFile(
        archivo.path,
        filename: archivo.path.split('/').last,
      );
    }

    final r = await _dio.post(
      '/visita_folio_guardar.php',
      data: FormData.fromMap(map),
    );
    _ensureOk(r.data);
  }

  static void _ensureOk(dynamic data) {
    if (data is Map && data['success'] == true) return;
    final msg = (data is Map ? (data['error'] ?? 'Error') : 'Error');
    throw Exception(msg.toString());
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';
}
