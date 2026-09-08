import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'app_http.dart';

class NotificationInbox {
  const NotificationInbox._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static void setUnread(int value) {
    unreadCount.value = math.max(0, value);
  }

  static void received() => setUnread(unreadCount.value + 1);
}

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.url,
    required this.category,
    required this.read,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String title;
  final String body;
  final String url;
  final String category;
  final bool read;
  final DateTime? createdAt;
  final DateTime? readAt;

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    return InboxNotification(
      id: _asInt(json['id']),
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      url: '${json['url'] ?? ''}',
      category: '${json['category'] ?? 'system'}',
      read: _asBool(json['read']),
      createdAt: _asDate(json['createdAt']),
      readAt: _asDate(json['readAt']),
    );
  }

  InboxNotification copyWith({bool? read, DateTime? readAt}) {
    return InboxNotification(
      id: id,
      title: title,
      body: body,
      url: url,
      category: category,
      read: read ?? this.read,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  int? get ticketId {
    final text = '$title $body $url';
    final patterns = <RegExp>[
      RegExp(r'ticket(?:\s+nuevo)?\s*#?\s*(\d+)', caseSensitive: false),
      RegExp(r'[?&](?:tiId|ticketId)=(\d+)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final value = int.tryParse(match?.group(1) ?? '');
      if (value != null && value > 0) return value;
    }
    return null;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  static bool _asBool(dynamic value) {
    return value == true || value == 1 || value == '1';
  }

  static DateTime? _asDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.theme = 'light',
    this.inApp = true,
    this.mail = true,
    this.ticketChanges = true,
    this.meet = true,
    this.visit = true,
    this.folio = true,
  });

  final String theme;
  final bool inApp;
  final bool mail;
  final bool ticketChanges;
  final bool meet;
  final bool visit;
  final bool folio;

  factory NotificationPreferences.fromSession(Map<String, dynamic> session) {
    final raw = session['preferences'];
    final json = raw is Map ? Map<String, dynamic>.from(raw) : session;
    bool flag(String key) {
      final value = json[key];
      if (value == null) return true;
      return value == true || value == 1 || value == '1';
    }

    return NotificationPreferences(
      theme: '${json['theme'] ?? 'light'}',
      inApp: flag('notifInApp'),
      mail: flag('notifMail'),
      ticketChanges: flag('notifTicketCambio'),
      meet: flag('notifMeet'),
      visit: flag('notifVisita'),
      folio: flag('notifFolio'),
    );
  }

  NotificationPreferences copyWith({
    String? theme,
    bool? inApp,
    bool? mail,
    bool? ticketChanges,
    bool? meet,
    bool? visit,
    bool? folio,
  }) {
    return NotificationPreferences(
      theme: theme ?? this.theme,
      inApp: inApp ?? this.inApp,
      mail: mail ?? this.mail,
      ticketChanges: ticketChanges ?? this.ticketChanges,
      meet: meet ?? this.meet,
      visit: visit ?? this.visit,
      folio: folio ?? this.folio,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'notifInApp': inApp,
    'notifMail': mail,
    'notifTicketCambio': ticketChanges,
    'notifMeet': meet,
    'notifVisita': visit,
    'notifFolio': folio,
  };
}

class NotificationsService {
  NotificationsService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<InboxNotification>> list({int limit = 80}) async {
    final response = await _dio.get(
      '/notifications_list.php',
      queryParameters: {'limit': limit},
    );
    final json = _map(response.data);
    _ensureSuccess(json);
    final values =
        json['notifications'] is List
            ? json['notifications'] as List
            : const <dynamic>[];
    final items =
        values
            .whereType<Map>()
            .map(
              (item) =>
                  InboxNotification.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
    NotificationInbox.setUnread(_asInt(json['unread']));
    return items;
  }

  Future<int> refreshUnread() async {
    final response = await _dio.get('/notification_status.php');
    final json = _map(response.data);
    _ensureSuccess(json);
    final unread = _asInt(json['unread']);
    NotificationInbox.setUnread(unread);
    return unread;
  }

  Future<void> markRead(int id) async {
    final response = await _dio.post(
      '/notification_read.php',
      data: {'id': id},
    );
    final json = _map(response.data);
    _ensureSuccess(json);
    await refreshUnread();
  }

  Future<void> markAllRead() async {
    final response = await _dio.post(
      '/notification_read.php',
      data: const {'all': true},
    );
    _ensureSuccess(_map(response.data));
    await refreshUnread();
  }

  Future<NotificationPreferences> loadPreferences() async {
    final response = await _dio.get('/me.php');
    final json = _map(response.data);
    _ensureSuccess(json);
    return NotificationPreferences.fromSession(json);
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    final response = await _dio.post(
      '/guardar_preferencias.php',
      data: preferences.toJson(),
    );
    _ensureSuccess(_map(response.data));
  }

  static Map<String, dynamic> _map(dynamic value) {
    return AppHttp.jsonMap(value);
  }

  static void _ensureSuccess(Map<String, dynamic> json) {
    if (json['success'] == true) return;
    throw StateError(
      (json['error'] ?? json['message'] ?? 'No se pudo completar la solicitud')
          .toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }
}
