import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mrsos/services/app_http.dart';
import '../widget/mr_skeleton.dart';

class HealthCheckDetailScreen extends StatefulWidget {
  const HealthCheckDetailScreen({
    super.key,
    required this.baseUrl, // http://192.168.3.7/php
    required this.hcId,
    required this.hcFolio, // "HC - INE - 12"
  });

  final String baseUrl;
  final int hcId;
  final String hcFolio;

  @override
  State<HealthCheckDetailScreen> createState() =>
      _HealthCheckDetailScreenState();
}

class _HealthCheckDetailScreenState extends State<HealthCheckDetailScreen> {
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  final Dio dio = AppHttp.I.dio;

  bool loading = true;
  Map<String, dynamic> hc = {};
  List<Map<String, dynamic>> equipos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await dio.get(
        '${widget.baseUrl}/detalle_health_check.php',
        queryParameters: {'hcId': widget.hcId},
      );

      final j = res.data;
      if (j is Map && j['success'] == true) {
        hc = Map<String, dynamic>.from(j['hc'] ?? {});
        final list = (j['equipos'] as List? ?? []).cast<dynamic>();
        equipos = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _fmtDateCard() {
    final s = (hc['hcFechaHora'] ?? '').toString(); // 2025-12-04 09:30:00
    final mins = _toInt(hc['hcDuracionMins']);
    final h = mins > 0 ? (mins / 60).round() : 4;
    if (s.length < 16) return '$s (${h}h)';
    return '${s.substring(0, 10)} ${s.substring(11, 16)} (${h}h)';
  }

  int _toInt(dynamic v) => int.tryParse('$v') ?? 0;

  String _equipImageUrl(String marca, String modelo, String version) {
    // http://192.168.3.7/img/Equipos/<marca>/<modelo sin version>.png
    // Tú dijiste: "metemos marcar aqui/modelo aqui sin version.png"
    final host = widget.baseUrl.replaceAll('/php', '');
    final m = Uri.encodeComponent(marca.trim());
    final model = Uri.encodeComponent(
      modelo.trim(),
    ); // sin version (como dijiste)
    return '$host/img/Equipos/$m/$model.png';
  }

  String _brandLogoUrl(String marca) {
    final host = widget.baseUrl.replaceAll('/php', '');
    final m = Uri.encodeComponent(marca.trim());
    return '$host/img/Marcas/$m.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          widget.hcFolio,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              // Fecha / hora card
              MRSkeleton(
                enabled: loading,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: mrPurple),
                      const SizedBox(width: 10),
                      const Text(
                        'Fecha y hora',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        loading ? '----' : _fmtDateCard(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Lista equipos (imagen grande + card)
              if (loading)
                ...List.generate(3, (_) => const _EquipoHCItemSkeleton())
              else
                ...equipos.map((e) {
                  final modelo = (e['eqModelo'] ?? '').toString();
                  final version = (e['eqVersion'] ?? '').toString();
                  final marca = (e['maNombre'] ?? '').toString();
                  final sn = (e['peSN'] ?? '').toString();

                  // tu regla: imagen equipo usa modelo sin version
                  final imgEq = _equipImageUrl(marca, modelo, version);
                  final imgBrand = _brandLogoUrl(marca);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 6,
                            child: Image.network(
                              imgEq,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    color: Colors.white,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.black26,
                                      size: 30,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$modelo ${version.isEmpty ? '' : version}'
                                          .trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'SN: $sn',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF6B667A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Image.network(
                                      imgBrand,
                                      height: 18,
                                      errorBuilder:
                                          (_, __, ___) =>
                                              const SizedBox(height: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipoHCItemSkeleton extends StatelessWidget {
  const _EquipoHCItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          SkeletonBox(height: 110, width: double.infinity, radius: 16),
          SizedBox(height: 10),
          SkeletonBox(height: 86, width: double.infinity, radius: 16),
        ],
      ),
    );
  }
}
