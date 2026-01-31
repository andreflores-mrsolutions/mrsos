import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class DioClient {
  DioClient(String baseUrl)
    : dio = Dio(
        BaseOptions(
          baseUrl:
              baseUrl, // ej: https://yellow-chicken-910471.hostingersite.com/php
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    final jar = CookieJar();
    dio.interceptors.add(CookieManager(jar));
  }

  final Dio dio;
}
