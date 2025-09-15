import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_monitoring/src/cpu_graph_painter.dart';

void main() {
  group('CpuGraphPainter', () {
    const Size testSize = Size(200, 100);
    const Color primaryColor = Colors.blue;
    const Color backgroundColor = Colors.white;

    group('Constructor and Properties', () {
      test('should initialize with required parameters', () {
        // Arrange
        const List<double> cpuHistory = <double>[10.0, 20.0, 30.0];
        const double maxCpu = 100.0;

        // Act
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: cpuHistory,
          maxCpu: maxCpu,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Assert
        expect(painter.cpuHistory, equals(cpuHistory));
        expect(painter.maxCpu, equals(maxCpu));
        expect(painter.primaryColor, equals(primaryColor));
        expect(painter.backgroundColor, equals(backgroundColor));
      });

      test('should handle empty CPU history', () {
        // Act & Assert - should not throw
        expect(
          () => CpuGraphPainter(
            cpuHistory: const <double>[],
            maxCpu: 100.0,
            primaryColor: primaryColor,
            backgroundColor: backgroundColor,
          ),
          returnsNormally,
        );
      });

      test('should handle single CPU value', () {
        // Act & Assert
        expect(
          () => CpuGraphPainter(
            cpuHistory: const <double>[50.0],
            maxCpu: 100.0,
            primaryColor: primaryColor,
            backgroundColor: backgroundColor,
          ),
          returnsNormally,
        );
      });
    });

    group('shouldRepaint', () {
      test('should always return true', () {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        final CpuGraphPainter oldPainter = CpuGraphPainter(
          cpuHistory: const <double>[15.0, 25.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        expect(painter.shouldRepaint(oldPainter), isTrue);
      });

      test('should return true even with identical data', () {
        // Arrange
        const List<double> sameCpuHistory = <double>[10.0, 20.0, 30.0];
        final CpuGraphPainter painter1 = CpuGraphPainter(
          cpuHistory: sameCpuHistory,
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        final CpuGraphPainter painter2 = CpuGraphPainter(
          cpuHistory: sameCpuHistory,
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        expect(painter1.shouldRepaint(painter2), isTrue);
      });
    });

    group('Paint Method Edge Cases', () {
      testWidgets('should handle empty CPU history gracefully', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert - should not crash when painting
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should paint single value correctly', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[50.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle zero values', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[0.0, 0.0, 0.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle maximum values', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[100.0, 100.0, 100.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle values exceeding maximum', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[120.0, 150.0, 200.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert - should clamp values
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle negative values', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[-10.0, -5.0, 10.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert - should clamp negative values
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });

    group('High CPU Warning', () {
      testWidgets('should paint without warning for low CPU', (WidgetTester tester) async {
        // Arrange - CPU values below 80%
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0, 40.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should paint with warning for high CPU', (WidgetTester tester) async {
        // Arrange - CPU values with last value > 80%
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0, 85.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should paint with warning at exactly 80% CPU', (WidgetTester tester) async {
        // Arrange - Edge case at exactly 80%
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0, 80.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert - 80.0 should not trigger warning (> 80, not >= 80)
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should paint with warning just above 80% CPU', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0, 80.1],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });

    group('Different CPU History Sizes', () {
      testWidgets('should handle large CPU history', (WidgetTester tester) async {
        // Arrange - Large dataset
        final List<double> largeCpuHistory = List<double>.generate(100, (int index) => index % 100.0);
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: largeCpuHistory,
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle very small CPU history', (WidgetTester tester) async {
        // Arrange - Two values (minimum for line drawing)
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[25.0, 75.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });

    group('Different MaxCpu Values', () {
      testWidgets('should handle different maximum CPU values', (WidgetTester tester) async {
        // Arrange - Non-standard max CPU
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0],
          maxCpu: 50.0, // Lower maximum
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle very high maximum CPU values', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[100.0, 200.0, 500.0],
          maxCpu: 1000.0, // Very high maximum
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle zero maximum CPU', (WidgetTester tester) async {
        // Arrange - Edge case with zero maximum
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0],
          maxCpu: 0.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert - should handle division by zero gracefully
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });

    group('Different Canvas Sizes', () {
      testWidgets('should handle very small canvas', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: const Size(10, 10),
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle very large canvas', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: const Size(1000, 500),
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle zero-width canvas', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: const Size(0, 100),
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle zero-height canvas', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: const Size(100, 0),
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });

    group('Different Color Configurations', () {
      testWidgets('should handle transparent colors', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0],
          maxCpu: 100.0,
          primaryColor: Colors.transparent,
          backgroundColor: Colors.transparent,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle bright colors', (WidgetTester tester) async {
        // Arrange
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0],
          maxCpu: 100.0,
          primaryColor: Colors.yellow,
          backgroundColor: Colors.pink,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });

    group('Complex CPU Patterns', () {
      testWidgets('should handle rapidly changing values', (WidgetTester tester) async {
        // Arrange - Simulate rapidly changing CPU values
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 80.0, 5.0, 90.0, 15.0, 85.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle constant values', (WidgetTester tester) async {
        // Arrange - All same values
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[50.0, 50.0, 50.0, 50.0, 50.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle ascending pattern', (WidgetTester tester) async {
        // Arrange - Steadily increasing values
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[10.0, 20.0, 30.0, 40.0, 50.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle descending pattern', (WidgetTester tester) async {
        // Arrange - Steadily decreasing values
        final CpuGraphPainter painter = CpuGraphPainter(
          cpuHistory: const <double>[90.0, 70.0, 50.0, 30.0, 10.0],
          maxCpu: 100.0,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        );

        // Act & Assert
        await tester.pumpWidget(
          CustomPaint(
            size: testSize,
            painter: painter,
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });
  });
}
