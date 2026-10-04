import 'package:flutter/material.dart';

/// The current gateway has a creation API, but no published history/detail API.
/// Keep old navigation entries safe without probing private PHP paths.
class HealthCheckDetailScreen extends StatelessWidget {
  const HealthCheckDetailScreen({
    super.key,
    required this.baseUrl,
    required this.hcId,
    required this.hcFolio,
  });
  final String baseUrl;
  final int hcId;
  final String hcFolio;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(hcFolio)),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'El servidor actual no publica la consulta de Health Checks. Contacta a soporte para confirmar el seguimiento de tu revisión.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
