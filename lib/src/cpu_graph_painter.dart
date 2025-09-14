import 'package:flutter/material.dart';

class CpuGraphPainter extends CustomPainter {
  CpuGraphPainter({
    required this.cpuHistory,
    required this.maxCpu,
    required this.primaryColor,
    required this.backgroundColor,
  });

  final List<double> cpuHistory;
  final double maxCpu;
  final Color primaryColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (cpuHistory.isEmpty) return;

    final Paint paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Draw grid lines for better CPU visualization
    final Paint gridPaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines for CPU percentages
    for (int i = 1; i < 4; i++) {
      final double y = size.height - (size.height * i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final Path path = Path();
    final Path fillPath = Path();

    final double stepX = size.width / (cpuHistory.length - 1);

    for (int i = 0; i < cpuHistory.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = (cpuHistory[i] / maxCpu).clamp(0.0, 1.0);
      final double y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Add warning indicator for high CPU usage
    if (cpuHistory.isNotEmpty && cpuHistory.last > 80) {
      final Paint warningPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(size.width - 10, 10),
        6,
        warningPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
