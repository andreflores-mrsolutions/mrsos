import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../firebase_options.dart';
import 'app_http.dart';
import 'local_notify.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // The OS displays notification messages. Do not duplicate them or open a
  // second PHP cookie jar in the background isolate. The inbox lives in the DB.
}

class DeviceRegistration {
  DeviceRegistration(this.dio);
  final Dio dio;
  static const deviceKey = 'push_device_id';

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(deviceKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(deviceKey, id);
    }
    return id;
  }

  Future<void> register(String token, String platform) async {
    if (!['android', 'ios'].contains(platform) ||
        token.length < 30 ||
        token.length > 512) {
      throw ArgumentError('Token o plataforma no válidos.');
    }
    final response = await dio.post(
      '/notif_token_guardar.php',
      data: {
        'deviceId': await deviceId(),
        'token': token,
        'platform': platform,
      },
    );
    final data = AppHttp.jsonMap(response.data);
    if (data['success'] != true) throw StateError(AppHttp.message(data));
  }

  Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(deviceKey);
    if (id == null) return;
    final response = await dio.post(
      '/notif_token_eliminar.php',
      data: {'deviceId': id},
    );
    final data = AppHttp.jsonMap(response.data);
    if (data['success'] != true) throw StateError(AppHttp.message(data));
  }
}

/// Firebase transports the alert; user_notifications remains the source of truth.
class PushService with WidgetsBindingObserver {
  PushService._();
  static final I = PushService._();
  final ValueNotifier<String> status = ValueNotifier(
    'Notificaciones aún no verificadas.',
  );
  VoidCallback? onOpenInbox;
  bool _ready = false, _unlocked = false, _pendingOpen = false;
  bool _busy = false;
  Timer? _timer;
  String? _registeredToken;
  final Set<String> _seen = {};

  Future<void> initialize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      status.value = 'Push disponible en la app Android y iOS.';
      return;
    }
    try {
      LocalNotify.onOpen = _open;
      await LocalNotify.init();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      // LocalNotify is the sole foreground presenter, on both platforms.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      FirebaseMessaging.onMessage.listen((message) async {
        if (!_unlocked) return;
        final key = message.messageId;
        if (key != null && !_seen.add(key)) return;
        if (_seen.length > 100) _seen.remove(_seen.first);
        await refreshInbox();
        final notification = message.notification;
        if (notification != null) {
          try {
            await LocalNotify.show(
              title: notification.title ?? 'MRSoS',
              body: notification.body ?? 'Tienes novedades de soporte.',
            );
          } catch (_) {
            status.value = 'Aviso recibido; consulta tu bandeja.';
          }
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen((_) => _open());
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) {
          _registeredToken = null;
          unawaited(sync());
        },
        onError: (_) {
          status.value = 'No se pudo renovar el registro del dispositivo.';
        },
      );
      _pendingOpen =
          _pendingOpen ||
          await FirebaseMessaging.instance.getInitialMessage() != null;
      WidgetsBinding.instance.addObserver(this);
      _ready = true;
    } catch (_) {
      status.value =
          'Firebase no pudo iniciar. Revisa la configuración de esta instalación.';
    }
  }

  void _open() {
    _pendingOpen = true;
    if (!_unlocked || onOpenInbox == null) return;
    _pendingOpen = false;
    onOpenInbox?.call();
  }

  void signedIn() {
    _unlocked = true;
    if (_pendingOpen) _open();
    if (!_ready) return;
    unawaited(sync());
    _startTimer();
  }

  void lock() {
    _unlocked = false;
    _timer?.cancel();
    _registeredToken = null;
    NotificationInbox.setUnread(0);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(sync()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _timer?.cancel();
    } else if (_unlocked) {
      unawaited(sync());
      _startTimer();
    }
  }

  Future<void> refreshInbox() async {
    if (!_unlocked) return;
    try {
      await NotificationsService(dio: AppHttp.I.dio).refreshUnread();
    } catch (_) {
      /* The inbox screen exposes its own retriable error state. */
    }
  }

  Future<void> sync({bool requestPermission = false}) async {
    if (!_ready || !_unlocked || _busy) return;
    _busy = true;
    try {
      final me = await AppHttp.I.refreshSession();
      if (!_unlocked) return;
      await refreshInbox();
      if (!NotificationPreferences.fromSession(me).inApp) {
        await DeviceRegistration(AppHttp.I.dio).remove();
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        _registeredToken = null;
        status.value = 'Avisos desactivados en tus preferencias compartidas.';
        return;
      }
      var settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (requestPermission ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (!_unlocked) return;
      if (![
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      ].contains(settings.authorizationStatus)) {
        await DeviceRegistration(AppHttp.I.dio).remove();
        _registeredToken = null;
        status.value =
            'Permiso denegado. Activa las notificaciones en Ajustes del teléfono.';
        return;
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await FirebaseMessaging.instance.getAPNSToken() == null) {
        status.value =
            'Esperando el registro de Apple (APNs). Revisa firma y capacidad Push.';
        return; // Retry on resume/timer; never call getToken before APNs is ready.
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (!_unlocked) return;
      if (token == null) {
        status.value = 'Firebase todavía no ha entregado un token.';
        return;
      }
      if (token != _registeredToken) {
        await DeviceRegistration(AppHttp.I.dio).register(
          token,
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        );
        _registeredToken = token;
      }
      status.value = 'Este dispositivo está registrado para recibir avisos.';
    } catch (error) {
      status.value = 'Registro pendiente: ${AppHttp.friendlyError(error)}';
    } finally {
      _busy = false;
    }
  }

  /// Unregister while the PHP session still identifies the outgoing account.
  Future<void> signOut() async {
    lock();
    // Wait for an in-flight registration before removing it.
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await DeviceRegistration(AppHttp.I.dio).remove();
    if (_ready) {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
    }
    _pendingOpen = false;
    await LocalNotify.clear();
  }

  Future<void> sessionExpired() async {
    lock();
    _pendingOpen = false;
    if (_ready) {
      try {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    await LocalNotify.clear();
  }
}
