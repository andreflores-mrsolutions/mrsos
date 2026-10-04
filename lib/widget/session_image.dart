import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/app_http.dart';

/// Protected media uses the same cookies as JSON APIs, not a separate HttpClient.
class SessionImage extends Image {
  SessionImage(
    String url, {
    super.key,
    super.width,
    super.height,
    super.fit,
    super.errorBuilder,
    super.loadingBuilder,
    super.color,
    super.colorBlendMode,
    super.alignment = Alignment.center,
  }) : super(image: SessionImageProvider(url));
}

class SessionImageProvider extends ImageProvider<SessionImageProvider> {
  SessionImageProvider(String path, {AppHttp? http})
    : http = http ?? AppHttp.I,
      url = AppConfig.mediaUrl(path, baseUrl: (http ?? AppHttp.I).baseUrl) {
    epoch = this.http.sessionEpoch;
    if (_observed[this.http] != true) {
      _observed[this.http] = true;
      this.http.addSessionListener(() {
        // No private avatar/equipment pixels survive an account change in cache.
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
    }
  }
  static final _observed = Expando<bool>();
  final AppHttp http;
  final String url;
  late final int epoch;

  @override
  Future<SessionImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  /// Kept separate from decoding so transport/security can be tested offline.
  Future<Uint8List> fetchBytes() async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        url.isEmpty ||
        !uri.path.startsWith('/img/') ||
        !RegExp(
          r'\.(png|jpe?g|webp|gif|ico)$',
          caseSensitive: false,
        ).hasMatch(uri.path)) {
      throw StateError('Imagen no disponible en el servidor seguro.');
    }
    if (epoch != http.sessionEpoch) throw StateError('La sesión cambió.');
    final cancel = CancelToken();
    final response = await http.dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'image/*'},
      ),
      cancelToken: cancel,
      onReceiveProgress: (received, total) {
        if (received > 10 * 1024 * 1024)
          cancel.cancel('Imagen demasiado grande.');
      },
    );
    if (epoch != http.sessionEpoch) throw StateError('La sesión cambió.');
    final bytes = response.data ?? [];
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw StateError('Imagen vacía o demasiado grande.');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  ImageStreamCompleter loadImage(
    SessionImageProvider key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _decode(decode), scale: 1);

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async {
    try {
      final bytes = await fetchBytes();
      final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      if (epoch != http.sessionEpoch) {
        codec.dispose();
        throw StateError('La sesión cambió.');
      }
      return codec;
    } catch (_) {
      await evict();
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SessionImageProvider &&
      identical(other.http, http) &&
      other.url == url &&
      other.epoch == epoch;
  @override
  int get hashCode => Object.hash(http, url, epoch);
}
