class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'MRSOS_API_BASE_URL',
    defaultValue: 'https://mrsos.com.mx/php',
  );

  static String get siteBaseUrl =>
      apiBaseUrl.replaceFirst(RegExp(r'/php/?$'), '');

  static String mediaUrl(dynamic path) {
    var value = '${path ?? ''}'.trim().replaceAll('\\', '/');
    if (value.isEmpty) return '';
    final absolute = Uri.tryParse(value);
    if (absolute != null && absolute.hasScheme) {
      if (absolute.origin != Uri.parse(siteBaseUrl).origin) return '';
      return absolute.toString();
    }
    while (value.startsWith('../')) {
      value = value.substring(3);
    }
    return Uri.parse('$siteBaseUrl/').resolve(value).toString();
  }

  static String avatarUrl(dynamic image, {String username = ''}) {
    final value = '${image ?? ''}'.trim();
    if (value.isEmpty || value == '0')
      return mediaUrl('img/Usuario/avatar_default.png');
    if (value == '1')
      return mediaUrl('img/Usuario/${Uri.encodeComponent(username)}.jpg');
    return mediaUrl(value.contains('/') ? value : 'img/Usuario/$value');
  }
}
