import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const portalLegalVersion = '2026-10-02.1';

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      for (final entry
          in const {
            'privacy': 'Aviso de privacidad',
            'terms': 'Términos y condiciones',
            'storage': 'Almacenamiento de la app',
          }.entries)
        TextButton(
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => LegalScreen(kind: entry.key, title: entry.value),
                ),
              ),
          child: Text(entry.value),
        ),
    ],
  );
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind, required this.title});
  final String kind;
  final String title;
  Future<List<dynamic>> _blocks() async {
    if (kind == 'storage')
      return [
        {'heading': true, 'text': 'Almacenamiento necesario en el teléfono'},
        {
          'text':
              'La app conserva cookies de sesión del servidor, datos básicos de tu cuenta, preferencias y archivos temporales para mostrar documentos. No guarda tu contraseña ni el código de correo. El código pendiente sólo permanece en memoria durante la verificación.',
        },
        {
          'text':
              'Sin mantener sesión, el servidor limita el acceso a una hora de inactividad o doce horas totales. Si eliges mantener sesión, puede recordarte hasta siete días. La biometría desbloquea el acceso local; no sustituye la autenticación y validación del servidor.',
        },
        {
          'text':
              'Firebase registra este dispositivo para avisos de servicio sólo después de acceder. Puedes cambiar tus preferencias y permisos de notificaciones en la app y en los ajustes del teléfono. Los códigos de seguridad por correo no se desactivan con esas preferencias.',
        },
        {
          'text':
              'Cerrar sesión elimina los datos locales de sesión y los archivos temporales administrados por la app. Los documentos que hayas exportado a otras aplicaciones permanecen bajo tu control.',
        },
      ];
    final data =
        jsonDecode(await rootBundle.loadString('assets/legal/portal.json'))
            as Map;
    if (data['version'] != portalLegalVersion)
      throw StateError('Documentos desactualizados.');
    return data[kind] as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: FutureBuilder<List<dynamic>>(
      future: _blocks(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('No se pudo abrir el documento.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Versión $portalLegalVersion · MR Support One Service'),
            const SizedBox(height: 20),
            for (final block in snapshot.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SelectableText(
                  block['text'] as String,
                  style:
                      block['heading'] == true
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.bodyLarge,
                ),
              ),
          ],
        );
      },
    ),
  );
}
