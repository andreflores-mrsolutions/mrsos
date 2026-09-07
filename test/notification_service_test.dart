import 'package:flutter_test/flutter_test.dart';
import 'package:mrsos/services/notification_service.dart';

void main() {
  group('InboxNotification', () {
    test('detecta el ticket desde el título compartido por la web', () {
      final notification = InboxNotification.fromJson({
        'id': 22,
        'title': 'Actualización del ticket #32',
        'body': 'El proceso cambió a revisión inicial.',
        'url': 'react-app/#/tickets',
        'category': 'ticket',
        'read': 0,
        'createdAt': '2026-08-17 07:18:20',
      });

      expect(notification.ticketId, 32);
      expect(notification.read, isFalse);
      expect(notification.createdAt, DateTime(2026, 8, 17, 7, 18, 20));
    });

    test('detecta tiId en una URL de notificación', () {
      final notification = InboxNotification.fromJson({
        'id': 1,
        'title': 'Caso actualizado',
        'body': 'Consulta el detalle.',
        'url': 'react-app/#/tickets?tiId=41',
        'category': 'ticket',
        'read': true,
      });

      expect(notification.ticketId, 41);
    });
  });

  test('las preferencias usan los valores del contrato de me.php', () {
    final preferences = NotificationPreferences.fromSession({
      'preferences': {
        'theme': 'light',
        'notifInApp': true,
        'notifMail': false,
        'notifTicketCambio': 1,
        'notifMeet': 0,
        'notifVisita': '1',
        'notifFolio': '0',
      },
    });

    expect(preferences.inApp, isTrue);
    expect(preferences.mail, isFalse);
    expect(preferences.ticketChanges, isTrue);
    expect(preferences.meet, isFalse);
    expect(preferences.visit, isTrue);
    expect(preferences.folio, isFalse);
  });
}
