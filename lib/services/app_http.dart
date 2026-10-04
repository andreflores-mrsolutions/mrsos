import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'session_store.dart';

/// Shared PHP session. Mutations are never automatically replayed.
class AppHttp {
  AppHttp._(this.baseUrl, this.dio, this.cookies) {
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
            if (login && options.extra['mrsMfaVerify'] != true) {
              csrfToken = null;
              _advanceSession();
              _expired = false;
              _refreshing = null;
            }
            final epoch = _epoch;
            if ((!['GET', 'HEAD', 'OPTIONS'].contains(options.method) ||
                    options.uri.path.contains('/api/')) &&
                !login &&
                !options.path.endsWith('/logout.php')) {
              if (csrfToken == null) await refreshSession();
              options.headers['X-CSRF-Token'] = csrfToken;
              if (!['GET', 'HEAD', 'OPTIONS'].contains(options.method)) {
                _addCsrfBody(options, csrfToken!);
              }
            }
            if (epoch != _epoch)
              throw StateError('La sesión cambió durante la solicitud.');
            options.extra['mrsSessionEpoch'] = epoch;
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
          if (response.requestOptions.extra['mrsSessionEpoch'] != _epoch) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                message: 'La sesión cambió durante la solicitud.',
              ),
            );
            return;
          }
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
            if (data['success'] == false ||
                (data['error'] != null && data['success'] != true)) {
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
          final requestEpoch = error.requestOptions.extra['mrsSessionEpoch'];
          if (requestEpoch != null && requestEpoch != _epoch) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                message: 'La sesión cambió durante la solicitud.',
              ),
            );
            return;
          }
          final status = error.response?.statusCode;
          if (status == 419) csrfToken = null;
          if (status == 401 &&
              !_isLogin(error.requestOptions.path) &&
              !_expired &&
              error.requestOptions.extra['mrsSessionEpoch'] == _epoch) {
            csrfToken = null;
            _expired = true;
            onSessionExpired?.call();
          }
          String? description;
          try {
            description = message(jsonMap(error.response?.data));
          } catch (_) {}
          if (status == 428 ||
              (status == 403 &&
                  description ==
                      'Debes cambiar tu contraseña antes de continuar.')) {
            onAccessRequired?.call();
          }
          handler.next(
            error.copyWith(
              message:
                  status == 419
                      ? 'La sesión de seguridad se renovará. Intenta de nuevo.'
                      : status == 401 && !_isLogin(error.requestOptions.path)
                      ? 'Tu sesión expiró. Inicia sesión nuevamente.'
                      : description ??
                          (status == 404
                              ? 'Esta función no está publicada en el servidor actual.'
                              : status == 503
                              ? 'El servidor no está disponible. Contacta al administrador si persiste.'
                              : error.message),
            ),
          );
        },
      ),
    );
    // Attach cookies after a possible me.php refresh; it may rotate PHPSESSID.
    // Validate responses before the jar accepts cookies from an old session.
    dio.interceptors.add(CookieManager(cookies));
  }
  final String baseUrl;
  final Dio dio;
  final CookieJar cookies;
  String? csrfToken;
  Future<Map<String, dynamic>>? _refreshing;
  Future<void>? _sessionWrite;
  int _epoch = 0;
  bool _expired = false;
  int get sessionEpoch => _epoch;
  final _sessionListeners = <void Function()>{};
  void addSessionListener(void Function() listener) =>
      _sessionListeners.add(listener);
  void removeSessionListener(void Function() listener) =>
      _sessionListeners.remove(listener);
  void _advanceSession() {
    _epoch++;
    for (final listener in _sessionListeners.toList()) {
      listener();
    }
  }

  void Function()? onSessionExpired;
  void Function()? onAccessRequired;
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
          'Cache-Control': 'no-store',
        },
      ),
    );
    return AppHttp._(url, dio, cookies ?? CookieJar());
  }

  Future<Map<String, dynamic>> refreshSession() {
    if (_refreshing != null) return _refreshing!;
    final epoch = _epoch;
    return _refreshing = _readSession().whenComplete(() {
      if (epoch == _epoch) _refreshing = null;
    });
  }

  Future<Map<String, dynamic>> _readSession() async {
    final response = await dio.get('/me.php');
    final user = jsonMap(response.data);
    if (user['success'] != true || user['usId'] == null) {
      throw StateError('No autenticado.');
    }
    if (user['forceChangePass'] != true) {
      await (_sessionWrite = SessionStore.saveServerSession(user));
    }
    return user;
  }

  Future<void> clearSession() async {
    _advanceSession();
    _refreshing = null;
    csrfToken = null;
    await _sessionWrite;
    await cookies.deleteAll();
    await SessionStore.clear();
  }

  static bool _isLogin(String path) =>
      path.endsWith('/login.php') || path.endsWith('/login_app.php');

  // Hostinger may strip custom headers. Match the web client's body fallback.
  // Never replay a mutation: the server may already have applied it.
  static void _addCsrfBody(RequestOptions options, String token) {
    final data = options.data;
    if (data is FormData) {
      final form = data.clone();
      form.fields.removeWhere((entry) => entry.key == 'csrf_token');
      form.fields.add(MapEntry('csrf_token', token));
      options.data = form;
    } else if (data == null || data is Map) {
      options.data = {...?data as Map?, 'csrf_token': token};
    } else if (data is String) {
      if (options.contentType?.contains('application/x-www-form-urlencoded') ==
          true) {
        options.data =
            Uri(
              queryParameters: {
                ...Uri.splitQueryString(data),
                'csrf_token': token,
              },
            ).query;
      } else if (options.contentType?.contains('application/json') == true) {
        options.data = jsonEncode({...jsonMap(data), 'csrf_token': token});
      }
    }
  }

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
