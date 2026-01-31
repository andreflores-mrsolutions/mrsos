import 'dio_client.dart';

class SessionInfo {
  final bool success;
  final String message;
  final String usId;
  final String userName;
  final int? clId;
  final String? rol;
  final int? pcId;

  SessionInfo({
    required this.success,
    required this.message,
    required this.usId,
    required this.userName,
    this.clId,
    this.rol,
    this.pcId,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
    success: j['success'] == true,
    message: (j['message'] ?? '').toString(),
    usId: (j['usId'] ?? '').toString(),
    userName: (j['userName'] ?? '').toString(),
    clId: j['clId'] is int ? j['clId'] : int.tryParse('${j['clId']}'),
    rol: j['rol']?.toString(),
    pcId: j['pcId'] is int ? j['pcId'] : int.tryParse('${j['pcId']}'),
  );
}

class SessionService {
  SessionService(this.client);
  final DioClient client;

  Future<SessionInfo> me() async {
    final res = await client.dio.get('/me.php');
    return SessionInfo.fromJson(Map<String, dynamic>.from(res.data));
  }
}
