class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'MRSOS_API_BASE_URL',
    defaultValue: 'https://mrsos.com.mx/php',
  );

  static String get siteBaseUrl =>
      apiBaseUrl.replaceFirst(RegExp(r'/php/?$'), '');
}
