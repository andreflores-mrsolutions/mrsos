class AppConfig {
  const AppConfig._();
  static const apiBaseUrl = String.fromEnvironment(
    'MRSOS_API_BASE_URL',
    defaultValue: 'https://mrsos.com.mx/php',
  );
  static String get siteBaseUrl =>
      apiBaseUrl.replaceFirst(RegExp(r'/php/?$'), '');

  /// Preserve public route names: mrsos-private is never part of a client URL.
  static String mediaUrl(dynamic path, {String? baseUrl}) {
    var value = '${path ?? ''}'.trim().replaceAll('\\', '/');
    if (value.isEmpty) return '';
    final root = Uri.parse(
      (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/php/?$'), '') + '/',
    );
    try {
      while (value.startsWith('../') || value.startsWith('./')) {
        value = value.substring(value.startsWith('../') ? 3 : 2);
      }
      final input = Uri.parse(value);
      if (input.hasAuthority &&
          (root.resolveUri(input).origin != root.origin ||
              input.userInfo.isNotEmpty))
        return '';
      if (input.hasScheme && !['https', 'http'].contains(input.scheme))
        return '';
      var route = Uri.decodeComponent(
        input.path,
      ).replaceFirst(RegExp(r'^/+'), '');
      if (route.contains('%') ||
          route.contains('\\') ||
          route.split('/').any((s) => s.startsWith('.')) ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(route))
        return '';
      while (route.startsWith('react-app/')) {
        route = route.substring('react-app/'.length);
      }
      if (RegExp(
        r'^(Clientes|Usuario|Usuarios|Ingeniero|Equipos|Marcas)/',
      ).hasMatch(route)) {
        route = 'img/$route';
      }
      while (route.startsWith('img/img/')) {
        route = route.substring(4);
      }
      if (RegExp(
        r'^(mrsos-private|uploads|logs|\.secrets)/|^backend/uploads/|^img/(Polizas|Tickets)/',
        caseSensitive: false,
      ).hasMatch(route))
        return '';
      return root
          .replace(path: '/$route', query: input.hasQuery ? input.query : null)
          .toString();
    } on FormatException {
      return '';
    }
  }

  static String avatarUrl(dynamic image, {String username = ''}) {
    final value = '${image ?? ''}'.trim();
    if (value.isEmpty || value == '0') {
      return mediaUrl('img/Usuario/avatar_default.png');
    }
    if (value == '1') {
      return mediaUrl('img/Usuario/${Uri.encodeComponent(username)}.jpg');
    }
    return mediaUrl(value.contains('/') ? value : 'img/Usuario/$value');
  }
}
