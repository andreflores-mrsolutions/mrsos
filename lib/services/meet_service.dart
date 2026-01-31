import 'dart:convert';
import 'package:dio/dio.dart';

class MeetService {
  MeetService({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<Map<String, dynamic>> generarSingle({
    required int tiId,
    required String tipo, // 'proponer' | 'asignar'
    required String fecha, // YYYY-MM-DD
    required String hora, // HH:MM:SS
    required String plataforma, // Google | Teams | Otra...
    required String link, // puede ser ''
    required String quienHara, // 'cliente' | 'ingeniero'
  }) async {
    final res = await _dio.post(
      '/meet_v2.php',
      data: FormData.fromMap({
        'accion': 'generar_single',
        'tiId': tiId,
        'tipo': tipo,
        'fecha': fecha,
        'hora': hora,
        'plataforma': plataforma,
        'link': link,
        'quienHara': quienHara,
      }),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> proponerVentanas({
    required int tiId,
    required String plataforma,
    required String link,
    required String quienHara, // 'cliente' | 'ingeniero'
    required List<Map<String, String>>
    propuestas, // [{'inicio':..., 'fin':...}]
  }) async {
    final res = await _dio.post(
      '/meet_v2.php',
      data: FormData.fromMap({
        'accion': 'proponer_ventanas',
        'tiId': tiId,
        'plataforma': plataforma,
        'link': link,
        'quienHara': quienHara,
        'propuestas': jsonEncode(propuestas),
      }),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> aceptarActual({required int tiId}) async {
    final res = await _dio.post(
      '/meet_v2.php',
      data: FormData.fromMap({'accion': 'aceptar_actual', 'tiId': tiId}),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> reprogramar({
    required int tiId,
    required String fecha,
    required String hora,
    required String plataforma,
    required String link,
  }) async {
    final res = await _dio.post(
      '/meet_v2.php',
      data: FormData.fromMap({
        'accion': 'reprogramar',
        'tiId': tiId,
        'fecha': fecha,
        'hora': hora,
        'plataforma': plataforma,
        'link': link,
      }),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> cancelar({
    required int tiId,
    String motivo = '',
  }) async {
    final res = await _dio.post(
      '/meet_v2.php',
      data: FormData.fromMap({
        'accion': 'cancelar',
        'tiId': tiId,
        'motivo': motivo,
      }),
    );
    return Map<String, dynamic>.from(res.data);
  }
}
