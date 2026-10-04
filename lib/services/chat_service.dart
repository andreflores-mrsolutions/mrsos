import 'package:dio/dio.dart';
import 'app_http.dart';

class ChatService {
  ChatService(this.dio);
  final Dio dio;
  String endpoint(String name) =>
      Uri.parse(
        '${dio.options.baseUrl}/',
      ).resolve('../dashboard/api/$name.php').toString();
  Future<List<Map<String, dynamic>>> list() async {
    final data = AppHttp.jsonMap((await dio.get(endpoint('chats_list'))).data);
    return (data['chats'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> thread(int ticketId) async => AppHttp.jsonMap(
    (await dio.get(
      endpoint('help_thread'),
      queryParameters: {'tiId': ticketId},
    )).data,
  );

  static bool canSend(String role) =>
      const ['CLI', 'MRSA', 'MRA'].contains(role);
  Future<void> send(
    int ticketId,
    String text, {
    required String role,
    int? activeThreadId,
  }) async {
    if (!canSend(role))
      throw StateError('Tu rol sólo permite consultar mensajes.');
    final message = text.trim();
    if (ticketId <= 0 || message.isEmpty || message.runes.length > 2000) {
      throw StateError('Escribe entre 1 y 2,000 caracteres.');
    }
    final replying = activeThreadId != null && activeThreadId > 0;
    final url =
        replying && role != 'CLI'
            ? Uri.parse(
              '${dio.options.baseUrl}/',
            ).resolve('../backend/api/help_reply.php').toString()
            : endpoint(replying ? 'help_reply' : 'help_message');
    final data = AppHttp.jsonMap(
      (await dio.post(
        url,
        data:
            replying
                ? {
                  'taId': activeThreadId,
                  'tarMensaje': message,
                  if (role != 'CLI') 'tarEsInterno': 0,
                }
                : {'tiId': ticketId, 'message': message},
      )).data,
    );
    if (data['success'] != true) throw StateError(AppHttp.message(data));
  }
}
