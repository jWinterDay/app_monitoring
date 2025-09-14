import 'package:flutter/material.dart';

class MemoryGraphPainter extends CustomPainter {
  MemoryGraphPainter({
    required this.memoryHistory,
    required this.maxMemory,
    required this.primaryColor,
    required this.backgroundColor,
    this.leakHistory,
    this.leakColor,
  });
  final List<double> memoryHistory;
  final double maxMemory;
  final Color primaryColor;
  final Color backgroundColor;
  final List<bool>? leakHistory;
  final Color? leakColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (memoryHistory.isEmpty) return;

    final Paint paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final Path path = Path();
    final Path fillPath = Path();

    final double stepX = size.width / (memoryHistory.length - 1);

    for (int i = 0; i < memoryHistory.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = (memoryHistory[i] / maxMemory).clamp(0.0, 1.0);
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

    // Draw professional memory leak indicators - Applies TRIZ LOCAL QUALITY: Industry-standard leak visualization
    if (leakHistory != null && leakColor != null && leakHistory!.length == memoryHistory.length) {
      for (int i = 0; i < leakHistory!.length; i++) {
        if (leakHistory![i]) {
          final double x = i * stepX;

          // Professional leak indicator - red vertical line with warning symbol
          canvas.drawLine(
            Offset(x, 0),
            Offset(x, size.height),
            Paint()
              ..color = leakColor!.withValues(alpha: 0.8)
              ..strokeWidth = 3
              ..style = PaintingStyle.stroke,
          );

          // Memory leak marker at the memory level
          final double normalizedValue = (memoryHistory[i] / maxMemory).clamp(0.0, 1.0);
          final double markerY = size.height - (normalizedValue * size.height);

          // Warning triangle for leak indication
          final Path trianglePath = Path();
          trianglePath.moveTo(x, markerY - 6);
          trianglePath.lineTo(x - 4, markerY + 2);
          trianglePath.lineTo(x + 4, markerY + 2);
          trianglePath.close();

          canvas.drawPath(
            trianglePath,
            Paint()
              ..color = leakColor!
              ..style = PaintingStyle.fill,
          );

          // White border for contrast
          canvas.drawPath(
            trianglePath,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1
              ..style = PaintingStyle.stroke,
          );

          // Add small "!" symbol for leak indication
          final TextPainter textPainter = TextPainter(
            text: const TextSpan(
              text: '!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 6,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(x - 2, markerY - 4));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
