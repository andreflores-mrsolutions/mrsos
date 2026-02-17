import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mrsos/services/device_id.dart';

import 'app_http.dart';
import 'push_token_service.dart';

class PushService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Permisos (Android 13+)
    final settings = await _fcm.requestPermission();
    log('Push permission: ${settings.authorizationStatus}');

    final tokenService = PushTokenService(
      dio: AppHttp.I.dio,
      savePath: '/notif_token_guardar.php',
    );
    final deviceId = await DeviceIdService.getOrCreate();
    // Token inicial
    final token = await _fcm.getToken();

    if (token != null) {
      log('FCM TOKEN: $token');
      try {
        final r = await tokenService.saveToken(
          token: token,
          platform: 'android',
          deviceId: deviceId,
        );
        debugPrint('SEND deviceId=$deviceId tokenLen=${token.length}');

        log('Token save: ${r.success} ${r.message}');
      } catch (e) {
        log('Token save error: $e');
      }
    }

    // IMPORTANTÍSIMO: cuando el token cambia (refresh)
    _fcm.onTokenRefresh.listen((newToken) async {
      log('FCM TOKEN REFRESH: $newToken');
      try {
        await tokenService.saveToken(token: newToken, platform: 'android');
      } catch (e) {
        log('Token refresh save error: $e');
      }
    });

    // Foreground
    FirebaseMessaging.onMessage.listen((msg) {
      log(
        'FCM onMessage: ${msg.notification?.title} | ${msg.notification?.body}',
      );
    });

    // Tap en notificación
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      log('FCM opened: ${msg.data}');
    });
  }
}
