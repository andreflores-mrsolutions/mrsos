import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'app_http.dart';

class DocumentService {
  static Future<void> openPdf(String path) async {
    final url = AppConfig.mediaUrl(path);
    if (url.isEmpty) throw StateError('El archivo no tiene una dirección válida de MRSoS.');
    final cancel = CancelToken();
    final response = await AppHttp.I.dio.get<List<int>>(url,
      cancelToken: cancel, options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (received > 50 * 1024 * 1024) cancel.cancel('El documento supera 50 MB.');
      });
    final bytes = response.data ?? [];
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw StateError('El servidor no entregó un PDF. Verifica tu sesión y la disponibilidad del documento.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mrsos-document-${const Uuid().v4()}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      throw StateError('No se pudo abrir el PDF. Instala o habilita un lector de documentos.');
    }
  }

  static Future<void> clearCache() async {
    final dir = await getTemporaryDirectory();
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.uri.pathSegments.last.startsWith('mrsos-document-')) {
        try { await entity.delete(); } catch (_) {}
      }
    }
  }
}
