import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EstadoAssistente { pronto, ouvindo, pensando, falando }

/// Esfera de pontos que reage ao estado do assistente.
class Esfera extends StatefulWidget {
  final EstadoAssistente estado;
  const Esfera({super.key, required this.estado});

  @override
  State<Esfera> createState() => _EsferaState();
}

class _EsferaState extends State<Esfera> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final List<List<double>> _pontos;
  double _nivel = 0.04;
  double _rot = 0;
  double _vel = 0.002;

  @override
  void initState() {
    super.initState();
    const n = 900;
    final rnd = math.Random(7);
    _pontos = List.generate(n, (i) {
      final y = 1 - (i / (n - 1)) * 2;
      final r = math.sqrt(1 - y * y);
      final th = i * 2.399963229728653;
      return [math.cos(th) * r, y, math.sin(th) * r, rnd.nextDouble() * math.pi * 2];
    });
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    double alvo;
    double velAlvo = 0.0026;
    switch (widget.estado) {
      case EstadoAssistente.ouvindo:
        alvo = 0.25 + 0.2 * math.sin(t * 9);
        break;
      case EstadoAssistente.falando:
        alvo = 0.22 + 0.18 * math.sin(t * 7);
        break;
      case EstadoAssistente.pensando:
        alvo = 0.16 + 0.1 * math.sin(t * 3.4);
        velAlvo = 0.014;
        break;
      case EstadoAssistente.pronto:
        alvo = 0.04 + 0.03 * math.sin(t * 1.2);
    }
    _nivel += (alvo - _nivel) * 0.2;
    _vel += (velAlvo - _vel) * 0.04;
    _rot += _vel;
    return CustomPaint(
      painter: _PintorEsfera(_pontos, _nivel, _rot, t),
      size: Size.infinite,
    );
  }
}

class _PintorEsfera extends CustomPainter {
  final List<List<double>> pontos;
  final double nivel, rot, t;
  _PintorEsfera(this.pontos, this.nivel, this.rot, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final raio = math.min(size.width, size.height) * 0.38 * (1 + nivel * 0.3);
    final cr = math.cos(rot), sr = math.sin(rot);
    final ci = math.cos(0.42), si = math.sin(0.42);
    final tinta = Paint();
    for (final p in pontos) {
      final onda = 1 + nivel * 0.5 * math.sin(p[3] + t * 6 + p[1] * 5);
      final x = p[0] * onda, y = p[1] * onda, z = p[2] * onda;
      final x1 = x * cr + z * sr;
      final z1 = -x * sr + z * cr;
      final y1 = y * ci - z1 * si;
      final z2 = y * si + z1 * ci;
      final prof = (z2 + 1.3) / 2.6;
      final esc = 1.4 / (1.9 - z2 * 0.5);
      final tam = 0.7 + 1.6 * prof;
      final alfa = (0.06 + 0.9 * prof * prof).clamp(0.05, 1.0);
      tinta.color = Colors.white.withOpacity(alfa);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx + x1 * raio * esc, cy + y1 * raio * esc),
          width: tam,
          height: tam,
        ),
        tinta,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorEsfera old) => true;
}
