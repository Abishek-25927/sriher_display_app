import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> particles = List.generate(20, (index) => Particle());

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
    return Scaffold(
      backgroundColor: Colors.white, // Pure White
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(particles, _controller.value),
                size: Size.infinite,
              );
            },
          ),
          widget.child,
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

  Particle() {
    reset();
  }

  void reset() {
    x = Random().nextDouble();
    y = Random().nextDouble();
    size = Random().nextDouble() * 50 + 10;
    speed = Random().nextDouble() * 0.0006 + 0.0002;
    opacity = Random().nextDouble() * 0.2 + 0.05;
    angle = Random().nextDouble() * pi * 2;
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

  ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      particle.update();

      // Draw "Bubble" effect
      final paint = Paint()
        ..color = Colors.blue.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12); // Airy feel

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );

      // Subtle rim light for the bubble
      final rimPaint = Paint()
        ..color = Colors.blue.withOpacity(particle.opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        rimPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
