import 'package:dio/dio.dart';
import 'app_http.dart';

class SurveyService {
  SurveyService(this.dio);
  final Dio dio;
  Future<void> submit(
    int ticketId, {
    required int rating,
    String comment = '',
  }) async {
    if (ticketId <= 0 || rating < 1 || rating > 5) {
      throw ArgumentError('Selecciona una calificación de 1 a 5.');
    }
    await _send('encuesta_save', {
      'tiId': ticketId,
      'calificacion': rating,
      'comentario': comment.trim(),
    });
  }

  Future<void> skip(int ticketId) => _send('encuesta_skip', {'tiId': ticketId});
  Future<void> _send(String name, Map<String, dynamic> data) async {
    final url =
        Uri.parse(
          '${dio.options.baseUrl}/',
        ).resolve('../dashboard/api/$name.php').toString();
    final result = AppHttp.jsonMap((await dio.post(url, data: data)).data);
    if (result['success'] != true) throw StateError(AppHttp.message(result));
  }
}
