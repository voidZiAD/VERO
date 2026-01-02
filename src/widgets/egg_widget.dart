import 'package:flutter/material.dart';

class EggWidget extends StatelessWidget {
  final String eggType; 
  final double size;

  const EggWidget({super.key, required this.eggType, this.size = 100});

  @override
  Widget build(BuildContext context) {
    Color baseColor = _getColor(eggType);
    
    return CustomPaint(
      size: Size(size, size),
      painter: EggPainter(color: baseColor),
    );
  }

  Color _getColor(String type) {
    if (type.contains("purple")) return const Color(0xFF7C4DFF);
    if (type.contains("blue")) return const Color(0xFF448AFF);
    if (type.contains("green")) return const Color(0xFF00E676);
    if (type.contains("red")) return const Color(0xFFFF5252);
    if (type.contains("orange")) return const Color(0xFFFFAB00);
    if (type.contains("gold")) return const Color(0xFFFFD700);
    if (type.contains("teal")) return const Color(0xFF1DE9B6);
    if (type.contains("pink")) return const Color(0xFFFF4081);
    return const Color(0xFF7C4DFF); 
  }
}

class EggPainter extends CustomPainter {
  final Color color;

  EggPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    final sx = w / 100;
    final sy = h / 100;

    final path = Path();
    path.moveTo(50 * sx, 2 * sy);
    path.cubicTo(25 * sx, 2 * sy, 10 * sx, 35 * sy, 10 * sx, 65 * sy);
    path.cubicTo(10 * sx, 90 * sy, 30 * sx, 98 * sy, 50 * sx, 98 * sy);
    path.cubicTo(70 * sx, 98 * sy, 90 * sx, 90 * sy, 90 * sx, 65 * sy);
    path.cubicTo(90 * sx, 35 * sy, 75 * sx, 2 * sy, 50 * sx, 2 * sy);
    path.close();

    final basePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, basePaint);

    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xD0FFFFFF),
          Color(0x40FFFFFF),
        ],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..blendMode = BlendMode.overlay; 
    canvas.drawPath(path, gradientPaint);

    final innerGlowPath = Path();
    innerGlowPath.moveTo(50 * sx, 15 * sy);
    innerGlowPath.cubicTo(35 * sx, 15 * sy, 20 * sx, 45 * sy, 20 * sx, 65 * sy);
    innerGlowPath.cubicTo(20 * sx, 85 * sy, 35 * sx, 90 * sy, 50 * sx, 90 * sy);
    innerGlowPath.cubicTo(65 * sx, 90 * sy, 80 * sx, 85 * sy, 80 * sx, 65 * sy);
    innerGlowPath.cubicTo(80 * sx, 45 * sy, 65 * sx, 15 * sy, 50 * sx, 15 * sy);
    innerGlowPath.close();

    final innerGlowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.4, 
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(innerGlowPath, innerGlowPaint);

    final outlinePath = Path();
    outlinePath.moveTo(50 * sx, 5 * sy);
    outlinePath.lineTo(30 * sx, 40 * sy);
    outlinePath.lineTo(20 * sx, 70 * sy);
    outlinePath.lineTo(50 * sx, 90 * sy);
    outlinePath.lineTo(80 * sx, 70 * sy);
    outlinePath.lineTo(70 * sx, 40 * sy);
    outlinePath.close();

    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(outlinePath, outlinePaint);

    final highlightPath = Path();
    highlightPath.moveTo(40 * sx, 20 * sy);
    highlightPath.lineTo(45 * sx, 35 * sy);
    highlightPath.lineTo(40 * sx, 50 * sy);
    highlightPath.lineTo(35 * sx, 35 * sy);
    highlightPath.close();

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant EggPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
