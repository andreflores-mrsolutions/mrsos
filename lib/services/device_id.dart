import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'mrsos_device_id';

  static Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final uuid = const Uuid().v4();
    await _storage.write(key: _key, value: uuid);
    return uuid;
  }
}
