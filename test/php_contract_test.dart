import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mrsos/services/app_http.dart';
import 'package:mrsos/services/auth_service.dart';
import 'package:mrsos/services/index_service.dart';
import 'package:mrsos/services/push_service.dart';
import 'package:mrsos/services/session_store.dart';
import 'package:mrsos/services/ticket_catalog_service.dart';
import 'package:mrsos/services/notification_service.dart';
import 'package:mrsos/config/app_config.dart';

class FakePhp implements HttpClientAdapter {
  FakePhp(this.reply);
  final ResponseBody Function(RequestOptions) reply;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    if (body != null) await body.drain<void>();
    requests.add(options);
    return reply(options);
  }
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, {int status = 200, bool cookie = false}) =>
  ResponseBody.fromString(jsonEncode(body), status, headers: {
    'content-type': ['application/json'],
    if (cookie) 'set-cookie': ['PHPSESSID=test-session; Path=/; HttpOnly; Secure'],
  });

const serverSession = {
  'success': true, 'usId': 42, 'usNombre': 'Cuenta de prueba', 'rol': 'CLI',
  'clId': 8, 'ucrRol': 'ADMIN_SEDE', 'csId': 7, 'czId': null,
  'csrfToken': 'test-csrf', 'usConfirmado': 'Si',
  'preferences': {'notifInApp': true, 'notifMail': false},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHttp http;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    http = AppHttp.create(baseUrl: 'https://test.invalid/php');
  });

  test('login uses the web contract and obtains the authoritative client scope', () async {
    final adapter = FakePhp((r) => r.uri.path.endsWith('/login.php')
      ? jsonResponse({'success': true, 'user': 'Name', 'csrfToken': 'login-token'}, cookie: true)
      : jsonResponse(serverSession));
    http.dio.httpClientAdapter = adapter;
    final result = await AuthService(dio: http.dio, loginPath: '/login.php')
      .login(usId: 'someone', usPass: 'test-only');
    expect(result.user!['usId'], 42);
    expect(result.user!['clId'], 8);
    expect(http.csrfToken, 'test-csrf');
    expect(adapter.requests.last.headers['cookie'], contains('PHPSESSID=test-session'));
    expect(adapter.requests.first.uri.path, '/php/login.php');
    expect(adapter.requests.first.headers['X-Requested-With'], 'XMLHttpRequest');
  });

  test('concurrent POSTs share one me.php request and send CSRF with JSON/multipart', () async {
    final adapter = FakePhp((r) => jsonResponse(
      r.uri.path.endsWith('/me.php') ? serverSession : {'success': true}));
    http.dio.httpClientAdapter = adapter;
    await Future.wait([
      http.dio.post('/notification_read.php', data: {'id': 1}),
      http.dio.post('/actualizar_perfil.php', data: FormData.fromMap({'usNombre': 'Test'})),
    ]);
    expect(adapter.requests.where((r) => r.uri.path.endsWith('/me.php')).length, 1);
    for (final r in adapter.requests.where((r) => r.method == 'POST')) {
      expect(r.headers['X-CSRF-Token'], 'test-csrf');
    }
  });

  test('419 never replays a mutation and clears the token for the next attempt', () async {
    http.csrfToken = 'expired';
    final adapter = FakePhp((_) => jsonResponse({'success': false, 'error': 'expired'}, status: 419));
    http.dio.httpClientAdapter = adapter;
    await expectLater(http.dio.post('/ticket_create.php', data: {'x': 1}), throwsA(isA<DioException>()));
    expect(adapter.requests.length, 1);
    expect(http.csrfToken, isNull);
  });

  test('401 expires the session but invalid login does not trigger global logout', () async {
    var expired = 0;
    http.onSessionExpired = () => expired++;
    http.dio.httpClientAdapter = FakePhp((_) => jsonResponse({'success': false}, status: 401));
    await expectLater(http.dio.get('/me.php'), throwsA(isA<DioException>()));
    await expectLater(http.dio.post('/login.php', data: {}), throwsA(isA<DioException>()));
    expect(expired, 1);
  });

  test('rejects cross-origin requests before sending cookies or CSRF', () async {
    final adapter = FakePhp((_) => jsonResponse({'success': true}));
    http.dio.httpClientAdapter = adapter;
    await expectLater(http.dio.get('https://external.invalid/file'), throwsA(isA<DioException>()));
    expect(adapter.requests, isEmpty);
  });

  test('HTTP 200 success=false and HTML are not accepted as empty successful data', () async {
    http.dio.httpClientAdapter = FakePhp((_) => jsonResponse({'success': false, 'error': 'Sin alcance'}));
    await expectLater(http.dio.get('/data.php'), throwsA(isA<DioException>()));
    http.dio.httpClientAdapter = FakePhp((_) => ResponseBody.fromString('<html>Login</html>', 200));
    await expectLater(http.dio.get('/data.php'), throwsA(isA<DioException>()));
  });

  test('device identifier survives logout; old account scope and preferences do not', () async {
    final device = DeviceRegistration(http.dio);
    final id = await device.deviceId();
    await SessionStore.saveServerSession(serverSession);
    await SessionStore.saveServerSession({...serverSession, 'csId': null, 'clId': 9});
    expect((await SessionStore().getProfile())['csId'], isNull);
    await http.clearSession();
    expect(await device.deviceId(), id);
    expect(await SessionStore.isLogged(), isFalse);
  });

  for (final platform in ['android', 'ios']) {
    test('registers $platform in user_push_devices and removes only this device', () async {
      http.csrfToken = 'csrf';
      final adapter = FakePhp((_) => jsonResponse({'success': true}));
      http.dio.httpClientAdapter = adapter;
      final device = DeviceRegistration(http.dio);
      await device.register('valid-fcm-token-for-contract-testing-12345', platform);
      final payload = adapter.requests.first.data as Map;
      expect(payload.keys.toSet(), {'deviceId', 'platform', 'token'});
      expect(payload['platform'], platform);
      await device.remove();
      expect(adapter.requests.last.uri.path, '/php/notif_token_eliminar.php');
      expect(adapter.requests.last.data['deviceId'], payload['deviceId']);
    });
  }

  test('catalog uses current endpoints, real site IDs and peId instead of model IDs', () async {
    http.csrfToken = 'csrf';
    http.dio.httpClientAdapter = FakePhp((r) => jsonResponse(r.uri.path.endsWith('sedes.php')
      ? {'success': true, 'sedes': [{'csId': '9', 'csNombre': 'Sede', 'healthCheckAvailable': true}]}
      : {'success': true, 'equipos': [
        {'peId': 1, 'eqId': 10, 'modelo': 'Same model', 'sn': 'A', 'healthCheckAvailable': true},
        {'peId': 2, 'eqId': 10, 'modelo': 'Same model', 'sn': 'B', 'healthCheckAvailable': true},
        {'peId': 3, 'eqId': 11, 'healthCheckAvailable': false},
      ]}));
    final catalog = TicketCatalogService(http.dio);
    expect(catalog.endpoint('ticket_create'), 'https://test.invalid/dashboard/api/ticket_create.php');
    expect((await catalog.sites()).single['csId'], 9);
    final equipment = await catalog.equipment(9, healthOnly: true);
    expect(equipment.map((e) => e['peId']), [1, 2]);
    expect(equipment.map((e) => e['peSN']), ['A', 'B']);
  });

  test('dashboard preserves server meta rather than recalculating action from process', () async {
    http.csrfToken = 'csrf';
    http.dio.httpClientAdapter = FakePhp((_) => jsonResponse({
      'success': true, 'meta': {'abiertos': 1, 'accion': 0, 'curso': 1},
      'tickets': [{'tiId': 12, 'tiProceso': 'meet', 'tiMeetEstado': 'confirmado',
        'requiereAccionCliente': false, 'csNombre': 'Sede', 'clNombre': 'Cliente'}],
    }));
    final data = await IndexService(dio: http.dio).obtenerTicketsSedes();
    expect(data['meta']['accion'], 0);
    expect(data['sedes'].single['tickets'].single['tiId'], 12);
  });

  test('notification preferences preserve every category in JSON', () async {
    http.csrfToken = 'csrf';
    final adapter = FakePhp((_) => jsonResponse({'success': true}));
    http.dio.httpClientAdapter = adapter;
    await NotificationsService(dio: http.dio).savePreferences(
      const NotificationPreferences(mail: false, meet: false, folio: false).copyWith(inApp: false));
    expect(adapter.requests.single.data['notifMeet'], false);
    expect(adapter.requests.single.data['notifFolio'], false);
    expect(adapter.requests.single.data['notifInApp'], false);
  });

  test('avatar uses canonical server paths, never the former LAN host', () {
    expect(AppConfig.avatarUrl('img/Usuario/a.webp'), 'https://mrsos.com.mx/img/Usuario/a.webp');
    expect(AppConfig.mediaUrl('https://external.invalid/secret'), '');
  });
}
