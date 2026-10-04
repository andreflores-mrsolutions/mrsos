import 'package:dio/dio.dart';
import 'app_http.dart';

class LogGuidesService {
  LogGuidesService(this.dio);
  final Dio dio;
  Future<List<Map<String, dynamic>>> list({int? peId}) async {
    final url = Uri.parse(
      '${dio.options.baseUrl}/',
    ).resolve('../dashboard/api/log_guides_list.php');
    final data = AppHttp.jsonMap(
      (await dio.get(
        url.toString(),
        queryParameters: {if (peId != null && peId > 0) 'peId': peId},
      )).data,
    );
    return (data['guides'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
