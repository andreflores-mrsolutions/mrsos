import 'package:flutter/material.dart';
import 'package:mrsos/screens/equipos/equipo_detalle_screen.dart';
import 'package:mrsos/services/app_http.dart';
import '../../services/equipos_service.dart';
import '../../widget/mr_skeleton.dart';

class MisEquiposPolizaScreen extends StatefulWidget {
  const MisEquiposPolizaScreen({
    super.key,
    required this.pcId,
    required this.titulo,
  });
  final int pcId;
  final String titulo;

  @override
  State<MisEquiposPolizaScreen> createState() => _MisEquiposPolizaScreenState();
}

class _MisEquiposPolizaScreenState extends State<MisEquiposPolizaScreen> {
  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  late final EquiposService _api;

  bool _loading = true;

  List<Map<String, dynamic>> _sedes = [];
  List<Map<String, dynamic>> _equipos = [];

  int? _csId;
  String _tipo = '';
  String _q = '';

  final _search = TextEditingController();

  // lo trae el JSON: { "prefix": "ENE" }
  String _prefix = '';

  final _tipos = const [
    '',
    'Servidor',
    'Storage',
    'Switch',
    'Firewall',
    'Router',
    'PC',
    'Laptop',
    'Software',
    'NAS',
  ];

  @override
  void initState() {
    super.initState();
    _api = EquiposService(dio: AppHttp.I.dio);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.porPoliza(
        pcId: widget.pcId,
        csId: _csId,
        tipo: _tipo,
        q: _q,
      );
      if (!mounted) return;

      if (r['success'] == true) {
        setState(() {
          _prefix = (r['prefix'] ?? '').toString();
          _sedes =
              (r['sedes'] is List)
                  ? List<Map<String, dynamic>>.from(r['sedes'])
                  : <Map<String, dynamic>>[];
          _equipos =
              (r['equipos'] is List)
                  ? List<Map<String, dynamic>>.from(r['equipos'])
                  : <Map<String, dynamic>>[];
        });
      } else {
        _toast((r['error'] ?? r['message'] ?? 'Error').toString());
      }
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _imgEquipo(String marca, String modelo) {
    // Nota: tu servidor usa espacios y carpetas; mejor encode para que no truene.
    final m = marca;
    final mo = modelo;
    return 'https://yellow-chicken-910471.hostingersite.com/img/Equipos/$m/$mo.png';
  }

  String _imgMarca(String marca) {
    final m = marca;
    return 'https://yellow-chicken-910471.hostingersite.com/img/Marcas/$m.png';
  }

  String _formatFecha(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s;
  }

  bool _isVigente(dynamic pcFechaFin) {
    final fin = (pcFechaFin ?? '').toString().trim();
    final dt = DateTime.tryParse(fin);
    if (dt == null)
      return true; // si no viene, asumimos vigente (como fallback)
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(dt.year, dt.month, dt.day);
    return !d1.isBefore(d0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          widget.titulo,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Stack(
            children: [
              // Fondo suave como el mock
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7F4FF), Colors.white],
                  ),
                ),
              ),

              ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  // Search
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: mrPurple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText:
                                  'Buscar (modelo, SN, sede, marca, tickets...)',
                            ),
                            onSubmitted: (v) {
                              _q = v.trim();
                              _load();
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _search.clear();
                            _q = '';
                            _load();
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFB8B6C6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filtros sedes
                  SizedBox(
                    height: 44,
                    child: MRSkeleton(
                      enabled: _loading,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _loading ? 4 : (_sedes.length + 1),
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          if (_loading) {
                            return const SkeletonBox(
                              height: 42,
                              width: 110,
                              radius: 14,
                            );
                          }

                          if (i == 0) {
                            final active = _csId == null;
                            return _Chip(
                              label: 'All',
                              active: active,
                              onTap: () {
                                setState(() => _csId = null);
                                _load();
                              },
                            );
                          }

                          final s = _sedes[i - 1];
                          final id = int.tryParse('${s['csId'] ?? 0}');
                          final nombre =
                              '${s['csNombre'] ?? s['nombre'] ?? ''}';
                          final active = id != null && id == _csId;

                          return _Chip(
                            label: nombre.isEmpty ? 'Sede' : nombre,
                            active: active,
                            onTap: () {
                              setState(() => _csId = id);
                              _load();
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Filtros tipo
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tipos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final t = _tipos[i];
                        final label = t.isEmpty ? 'Todos' : t;
                        final active = _tipo == t;
                        return _Chip(
                          label: label,
                          active: active,
                          onTap: () {
                            setState(() => _tipo = t);
                            _load();
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ LISTA CON EL MISMO ESTILO DE CARD QUE EN MIS EQUIPOS
                  ...List.generate(_loading ? 3 : _equipos.length, (i) {
                    if (_loading) return const _EquipoBigCardSkeleton();

                    final e = _equipos[i];
                    final peId = int.tryParse('${e['peId'] ?? 0}') ?? 0;

                    final modelo = '${e['eqModelo'] ?? 'Equipo'}';
                    final marca = '${e['maNombre'] ?? ''}'.trim();
                    final sn = '${e['peSN'] ?? ''}'.trim();
                    final sede = '${e['csNombre'] ?? ''}'.trim();

                    final fi = _formatFecha(e['pcFechaInicio']);
                    final ff = _formatFecha(e['pcFechaFin']);

                    final pcIdent =
                        (e['pcIdentificador'] ?? '').toString().trim();
                    final chipPoliza =
                        pcIdent.isNotEmpty ? 'Póliza $pcIdent' : 'Póliza';

                    final vigente = _isVigente(e['pcFechaFin']);
                    final chipVigencia =
                        ff.isEmpty
                            ? (vigente ? 'Póliza vigente' : 'Póliza vencida')
                            : (vigente
                                ? 'Póliza vigente (vence $ff)'
                                : 'Póliza vencida (venció $ff)');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: InkWell(
                        onTap: () {
                          if (peId <= 0) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => MisEquiposDetalleScreen(peId: peId),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(26),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 26,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Imagen equipo
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: AspectRatio(
                                  aspectRatio: 16 / 6.2,
                                  child: Image.network(
                                    _imgEquipo(
                                      marca,
                                      modelo.replaceAll('  ', ' '),
                                    ),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) {
                                      return Container(
                                        color: Colors.white,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.dns_rounded,
                                          size: 40,
                                          color: Color(0xFFE0DBF7),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Modelo
                              Text(
                                modelo,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F1B2E),
                                ),
                              ),

                              const SizedBox(height: 2),

                              // Fechas + sede (como mock)
                              Text(
                                [
                                  if (fi.isNotEmpty) fi,
                                  if (ff.isNotEmpty) ff,
                                  if (sede.isNotEmpty) sede,
                                ].join(' - '),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: Color(0xFF6B667A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Chips
                              _ChipBlue(text: chipPoliza),
                              const SizedBox(height: 6),
                              _ChipGreen(text: chipVigencia, danger: !vigente),

                              const SizedBox(height: 10),

                              if (sn.isNotEmpty)
                                Text(
                                  'SN: $sn',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1F1B2E),
                                  ),
                                ),

                              const SizedBox(height: 10),

                              // Logo marca grande
                              SizedBox(
                                height: 54,
                                child: Image.network(
                                  _imgMarca(marca),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) {
                                    return Text(
                                      marca.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1F1B2E),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // (opcional) prefijo para tickets si lo quieres mostrar acá
                              // if (_prefix.isNotEmpty) Text('Prefijo: $_prefix'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  static const mrPurple = Color.fromARGB(255, 15, 24, 76);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? mrPurple : const Color.fromARGB(255, 230, 232, 255),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : mrPurple,
          ),
        ),
      ),
    );
  }
}

class _ChipBlue extends StatelessWidget {
  const _ChipBlue({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD8EEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1C7ED6),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChipGreen extends StatelessWidget {
  const _ChipGreen({required this.text, this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? const Color(0xFFFFE7EC) : const Color(0xFFDFF7E8);
    final fg = danger ? const Color(0xFFB3261E) : const Color(0xFF1F8A4C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EquipoBigCardSkeleton extends StatelessWidget {
  const _EquipoBigCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Column(
          children: [
            SkeletonBox(height: 110, width: double.infinity, radius: 18),
            SizedBox(height: 12),
            SkeletonBox(height: 20, width: 220),
            SizedBox(height: 8),
            SkeletonBox(height: 14, width: 260),
            SizedBox(height: 12),
            SkeletonBox(height: 30, width: 200, radius: 999),
            SizedBox(height: 10),
            SkeletonBox(height: 30, width: 260, radius: 999),
            SizedBox(height: 12),
            SkeletonBox(height: 16, width: 240),
            SizedBox(height: 10),
            SkeletonBox(height: 44, width: 200),
          ],
        ),
      ),
    );
  }
}
