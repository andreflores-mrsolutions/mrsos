import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../main.dart';

class PushRouter {
  static Map<String, dynamic>? pendingArgs;

  static void capture(RemoteMessage msg) {
    final data = msg.data;
    final type = data['type']?.toString();
    final tiIdStr = data['tiId']?.toString();
    final tiId = int.tryParse(tiIdStr ?? '');
    if (type == null || tiId == null) return;

    // Ruta única a detalle ticket
    pendingArgs = {
      'route': '/ticketDetalle',
      'args': {
        'tiId': tiId,
        'folio': data['folio']?.toString() ?? '',
        'type': type,
      },
    };
  }

  static Future<void> openIfAny() async {
    final p = pendingArgs;
    if (p == null) return;
    pendingArgs = null;

    final route = p['route'] as String;
    final args = p['args'] as Map<String, dynamic>;

    // Ejecuta navegación cuando UI esté lista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamed(route, arguments: args);
    });
  }
}
