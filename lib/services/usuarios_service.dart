import 'package:dio/dio.dart';
import 'app_http.dart';

class UsuariosService {
  UsuariosService({required Dio dio}) : _dio = dio;
  final Dio _dio;
  String _endpoint(String name) =>
      Uri.parse(
        '${_dio.options.baseUrl}/',
      ).resolve('../backend/api/clientes/$name.php').toString();

  Future<int> _clientId() async {
    final session = AppHttp.jsonMap((await _dio.get('/me.php')).data);
    final id = int.tryParse('${session['clId']}') ?? 0;
    if (id <= 0 ||
        ![
          'ADMIN_GLOBAL',
          'ADMIN_ZONA',
          'ADMIN_SEDE',
        ].contains(session['ucrRol'])) {
      throw StateError(
        'La consulta de personas requiere una cuenta administradora de cliente.',
      );
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> _users(int clientId) async {
    final data = AppHttp.jsonMap(
      (await _dio.get(
        _endpoint('usuario_cli_list'),
        queryParameters: {'clId': clientId},
      )).data,
    );
    return (data['usuarios'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> listado({String q = ''}) async {
    final rows = await _users(await _clientId());
    final query = q.trim().toLowerCase();
    final users =
        rows
            .where(
              (u) => [
                u['usNombre'],
                u['usAPaterno'],
                u['usAMaterno'],
                u['usCorreo'],
                u['usUsername'],
              ].any((value) => '${value ?? ''}'.toLowerCase().contains(query)),
            )
            .map(
              (u) => {
                ...u,
                'nombre':
                    '${u['usNombre'] ?? ''} ${u['usAPaterno'] ?? ''} ${u['usAMaterno'] ?? ''}'
                        .trim(),
                'username': u['usUsername'],
                'avatar': u['usImagen'],
                'rol':
                    u['usEstatus'], // API publishes status, not per-site roles.
              },
            )
            .toList();
    return {
      'success': true,
      'sedes': [
        if (users.isNotEmpty)
          {'titulo': 'Personas de tu cuenta', 'usuarios': users},
      ],
    };
  }

  Future<Map<String, dynamic>> detalle(int usId) async {
    final clientId = await _clientId();
    final matches = (await _users(
      clientId,
    )).where((u) => int.tryParse('${u['usId']}') == usId);
    if (matches.length != 1)
      throw StateError('Usuario no disponible en tu cuenta.');
    return {...matches.single, 'clId': clientId};
  }

  Future<void> actualizar(int usId, Map<String, dynamic> fields) async {
    final clientId = await _clientId();
    await _dio.post(
      _endpoint('usuario_cli_update'),
      data: {
        for (final key in [
          'usNombre',
          'usAPaterno',
          'usAMaterno',
          'usCorreo',
          'usTelefono',
          'usUsername',
          'usPass',
        ])
          if (fields.containsKey(key)) key: fields[key],
        'clId': clientId,
        'usId': usId,
      },
    );
  }

  Future<void> cambiarEstatus(int usId, String to) async {
    if (!['Activo', 'Inactivo'].contains(to))
      throw StateError('Estatus inválido.');
    await _dio.post(
      _endpoint('usuario_cli_toggle'),
      data: {'clId': await _clientId(), 'usId': usId, 'to': to},
    );
  }
}
