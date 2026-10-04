import 'package:dio/dio.dart';
import 'app_http.dart';

class EmailChangeService {
  EmailChangeService(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    final data = AppHttp.jsonMap(
      (await dio.post('/email_change.php', data: payload)).data,
    );
    if (data['success'] != true) throw StateError(AppHttp.message(data));
    return data;
  }

  Future<void> begin(String email, String password) async {
    if (password.isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw StateError('Indica un correo válido y tu contraseña actual.');
    }
    await _post({
      'action': 'begin',
      'email': email.trim(),
      'password': password,
    });
  }

  Future<String> verify(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim()))
      throw StateError('Escribe seis dígitos.');
    final data = await _post({'action': 'verify', 'code': code.trim()});
    return '${data['email'] ?? ''}';
  }
}
