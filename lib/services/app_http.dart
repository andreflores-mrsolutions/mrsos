import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'session_store.dart';

/// Shared PHP session. Mutations are never automatically replayed.
class AppHttp {
  AppHttp._(this.baseUrl, this.dio, this.cookies) {
    dio.interceptors.add(CookieManager(cookies));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.uri.origin != Uri.parse(baseUrl).origin) {
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'El recurso no pertenece al servidor de MRSoS.',
              ),
            );
            return;
          }
          try {
            final login = _isLogin(options.path);
            if (login) csrfToken = null;
            if ((!['GET', 'HEAD', 'OPTIONS'].contains(options.method) ||
                    options.uri.path.contains('/dashboard/api/')) &&
                !login &&
                !options.path.endsWith('/logout.php')) {
              if (csrfToken == null) await refreshSession();
              options.headers['X-CSRF-Token'] = csrfToken;
            }
            handler.next(options);
          } catch (e) {
            handler.reject(
              e is DioException
                  ? e
                  : DioException(
                    requestOptions: options,
                    message: 'No se pudo validar tu sesión.',
                  ),
            );
          }
        },
        onResponse: (response, handler) {
          if (response.requestOptions.responseType == ResponseType.json) {
            try {
              response.data = jsonMap(response.data);
            } catch (_) {
              handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  message: 'El servidor no devolvió JSON válido.',
                ),
              );
              return;
            }
            final data = response.data as Map<String, dynamic>;
            final token = data['csrfToken']?.toString();
            if (token != null && token.isNotEmpty) csrfToken = token;
            if (data['success'] == false) {
              handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  message: message(data),
                ),
              );
              return;
            }
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode;
          if (status == 419) csrfToken = null;
          if (status == 401 && !_isLogin(error.requestOptions.path)) {
            csrfToken = null;
            onSessionExpired?.call();
          }
          String? description;
          try {
            description = message(jsonMap(error.response?.data));
          } catch (_) {}
          handler.next(
            error.copyWith(
              message:
                  status == 419
                      ? 'La sesión de seguridad se renovará. Intenta de nuevo.'
                      : status == 401
                      ? 'Tu sesión expiró. Inicia sesión nuevamente.'
                      : description ?? error.message,
            ),
          );
        },
      ),
    );
  }
  final String baseUrl;
  final Dio dio;
  final CookieJar cookies;
  String? csrfToken;
  Future<Map<String, dynamic>>? _refreshing;
  void Function()? onSessionExpired;
  static AppHttp? _i;
  static AppHttp get I => _i!;

  static Future<void> init({required String baseUrl}) async {
    final dir = await getApplicationDocumentsDirectory();
    _i = create(
      baseUrl: baseUrl,
      cookies: PersistCookieJar(storage: FileStorage('${dir.path}/.cookies')),
    );
  }

  /// In-memory jars/adapters allow tests without production requests.
  static AppHttp create({required String baseUrl, CookieJar? cookies}) {
    final url = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final dio = Dio(
      BaseOptions(
        baseUrl: url,
        followRedirects: false,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );
    return AppHttp._(url, dio, cookies ?? CookieJar());
  }

  Future<Map<String, dynamic>> refreshSession() =>
      _refreshing ??= _readSession().whenComplete(() => _refreshing = null);

  Future<Map<String, dynamic>> _readSession() async {
    final response = await dio.get('/me.php');
    final user = jsonMap(response.data);
    if (user['success'] != true || user['usId'] == null) {
      throw StateError('No autenticado.');
    }
    if (user['forceChangePass'] != true)
      await SessionStore.saveServerSession(user);
    return user;
  }

  Future<void> clearSession() async {
    csrfToken = null;
    await cookies.deleteAll();
    await SessionStore.clear();
  }

  static bool _isLogin(String path) =>
      path.endsWith('/login.php') || path.endsWith('/login_app.php');

  static Map<String, dynamic> jsonMap(dynamic data) {
    if (data is String)
      data = jsonDecode(data.replaceFirst('\uFEFF', '').trim());
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Respuesta inválida del servidor.');
  }

  static String message(Map<String, dynamic> data) =>
      '${data['error'] ?? data['message'] ?? 'No se pudo completar la solicitud.'}';

  static String friendlyError(Object error) {
    if (error is DioException) {
      if ([
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ].contains(error.type)) {
        return 'No se pudo contactar al servidor. Revisa tu conexión.';
      }
      return error.message ?? 'No se pudo completar la solicitud.';
    }
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }
}
