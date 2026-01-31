import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart' show PersistCookieJar;
import 'package:path_provider/path_provider.dart';

class AppHttp {
  AppHttp._(this.baseUrl, this.dio);

  final String baseUrl;
  final Dio dio;

  static AppHttp? _i;
  static AppHttp get I => _i!;

  static Future<void> init({required String baseUrl}) async {
    // ✅ cookies persistentes (se guardan en disco)
    final dir = await getApplicationDocumentsDirectory();
    final jar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies'));

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(CookieManager(jar));

    _i = AppHttp._(baseUrl, dio);
  }
}
