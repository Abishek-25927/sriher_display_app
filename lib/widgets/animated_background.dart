import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget? child;
  const AnimatedBackground({super.key, this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> particles = List.generate(25, (index) => Particle());
  Offset _mousePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        setState(() {
          _mousePosition = event.localPosition;
        });
      },
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(
                  particles,
                  _controller.value,
                  _mousePosition,
                ),
                size: Size.infinite,
              );
            },
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class Particle {
  late double x;
  late double y;
  late double size;
  late double speed;
  late double opacity;
  late double angle;
  late Color color;

  Particle() {
    reset();
  }

  void reset() {
    x = Random().nextDouble();
    y = Random().nextDouble();
    size = Random().nextDouble() * 40 + 5;
    speed = Random().nextDouble() * 0.0004 + 0.0001;
    opacity = Random().nextDouble() * 0.15 + 0.05;
    angle = Random().nextDouble() * pi * 2;
    color = Random().nextBool()
        ? const Color(0xFF3B82F6)
        : const Color(0xFF10B981);
  }

  void update() {
    x += cos(angle) * speed;
    y += sin(angle) * speed;

    if (x < -0.2) x = 1.2;
    if (x > 1.2) x = -0.2;
    if (y < -0.2) y = 1.2;
    if (y > 1.2) y = -0.2;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final Offset mousePos;

  ParticlePainter(this.particles, this.progress, this.mousePos);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      particle.update();

      // Parallax effect based on mouse position
      double dx = 0;
      double dy = 0;
      if (mousePos != Offset.zero) {
        double relX = (mousePos.dx / size.width) - 0.5;
        double relY = (mousePos.dy / size.height) - 0.5;
        dx = relX * (particle.size * 0.5);
        dy = relY * (particle.size * 0.5);
      }

      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 0.4);

      canvas.drawCircle(
        Offset(particle.x * size.width + dx, particle.y * size.height + dy),
        particle.size,
        paint,
      );

      // Subtle glow
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(particle.opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(
        Offset(particle.x * size.width + dx, particle.y * size.height + dy),
        particle.size * 1.2,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
