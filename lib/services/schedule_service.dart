import 'package:dio/dio.dart';
import 'app_http.dart';

class ScheduleService {
  ScheduleService(this.dio);
  final Dio dio;
  String endpoint(String path) =>
      Uri.parse('${dio.options.baseUrl}/').resolve('../$path').toString();

  Future<Map<String, dynamic>> load(
    int ticketId, {
    required bool visit,
  }) async => AppHttp.jsonMap(
    (await dio.get(
      endpoint('dashboard/api/${visit ? 'visita' : 'meet'}_get.php'),
      queryParameters: {'tiId': ticketId},
    )).data,
  );

  Future<Map<String, dynamic>> accept(
    int proposalId, {
    required bool visit,
    String platform = '',
    String link = '',
    String delivery = 'link',
  }) async {
    if (proposalId <= 0) throw ArgumentError('Propuesta inválida.');
    if (!visit) {
      final uri = Uri.tryParse(link.trim());
      if (platform.trim().isEmpty ||
          platform.trim().length > 80 ||
          !['link', 'email'].contains(delivery) ||
          (delivery == 'link' &&
              (uri == null ||
                  uri.scheme != 'https' ||
                  uri.host.isEmpty ||
                  uri.userInfo.isNotEmpty))) {
        throw ArgumentError(
          'Indica la plataforma y un enlace HTTPS, o el envío por correo.',
        );
      }
    }
    final response = await dio.post(
      endpoint('dashboard/api/${visit ? 'visita' : 'meet'}_accept.php'),
      data: {
        visit ? 'vpId' : 'mpId': proposalId,
        if (!visit) ...{
          'plataforma': platform.trim(),
          'linkDelivery': delivery,
          'enlace': delivery == 'email' ? '' : link.trim(),
        },
      },
    );
    final data = AppHttp.jsonMap(response.data);
    if (data['success'] != true) throw StateError(AppHttp.message(data));
    return data;
  }

  Future<void> propose({
    required int ticketId,
    required bool visit,
    required bool internal,
    required List<DateTime> starts,
    required int minutes,
    String platform = '',
    String link = '',
    String reason = '',
  }) async {
    if (starts.length != 3 ||
        starts.toSet().length != 3 ||
        starts.any((date) => !date.isAfter(DateTime.now())) ||
        minutes < 1) {
      throw ArgumentError('Indica tres horarios futuros y diferentes.');
    }
    String date(DateTime d) =>
        d.toIso8601String().substring(0, 19).replaceFirst('T', ' ');
    final slots =
        starts
            .map(
              (d) => {
                'inicio': date(d),
                'fin': date(d.add(Duration(minutes: minutes))),
              },
            )
            .toList();
    final path =
        internal
            ? 'backend/api/${visit ? 'visita_propose' : 'meet_create'}.php'
            : 'dashboard/api/${visit ? 'visita' : 'meet'}_create.php';
    final data = <String, dynamic>{'tiId': ticketId};
    if (internal) {
      data['opciones'] = visit ? slots : starts.map(date).toList();
      if (!visit)
        data.addAll({'plataforma': platform, 'link': link, 'motivo': reason});
    } else {
      data['slots'] = slots;
      if (!visit)
        data.addAll({
          'modo': 'remoto',
          'plataforma': platform,
          'enlace': link,
          'motivo': reason,
        });
    }
    final result = AppHttp.jsonMap(
      (await dio.post(endpoint(path), data: data)).data,
    );
    if (result['success'] != true) throw StateError(AppHttp.message(result));
  }
}
