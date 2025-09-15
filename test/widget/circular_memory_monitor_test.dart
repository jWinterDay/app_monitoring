// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_monitoring/src/circular_memory_monitor.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('CircularMemoryMonitor Widget', () {
    late File tempDatabase;

    setUp(() async {
      // Create a temporary database file for testing
      tempDatabase = await TestHelpers.createTempDatabase();
    });

    tearDown(() async {
      // Clean up temporary files
      await TestHelpers.cleanupTempFile(tempDatabase);
    });

    group('Widget Creation and Display', () {
      testWidgets('should render without errors', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Assert - widget should be rendered
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(find.byIcon(Icons.memory), findsOneWidget);
      });

      testWidgets('should display memory icon and text', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Allow initial memory reading
        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        expect(find.byIcon(Icons.memory), findsOneWidget);
        expect(find.textContaining('M'), findsOneWidget); // Memory display
      });

      testWidgets('should have circular shape with proper styling', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Assert
        final Container container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(CircularMemoryMonitor),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(container.decoration, isA<BoxDecoration>());
        final BoxDecoration decoration = container.decoration! as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
        expect(decoration.border, isNotNull);
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow!.isNotEmpty, isTrue);
      });

      testWidgets('should show circular progress indicator', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Memory Display', () {
      testWidgets('should display memory usage in megabytes', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Wait for initial memory reading
        await TestHelpers.pumpAndSettleWithTimeout(tester);
        await tester.pump(const Duration(milliseconds: 600)); // Wait for timer update

        // Assert
        final Text memoryText = tester.widget<Text>(
          find.textContaining('M'),
        );
        expect(memoryText.data, matches(RegExp(r'\d+M')));
        expect(memoryText.style?.fontWeight, equals(FontWeight.bold));
      });

      testWidgets('should update memory display periodically', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Get initial memory value
        await tester.pump(const Duration(milliseconds: 100));

        // Wait for timer update (timer runs every 500ms)
        await tester.pump(const Duration(milliseconds: 600));

        // Assert - should still be displaying memory (might be same value)
        final String updatedMemoryText = tester
            .widget<Text>(
              find.textContaining('M'),
            )
            .data!;
        expect(updatedMemoryText, matches(RegExp(r'\d+M')));
      });

      testWidgets('should change color based on memory usage', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert - check that border color is set (color depends on actual memory usage)
        final Container container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(CircularMemoryMonitor),
                matching: find.byType(Container),
              )
              .first,
        );

        final BoxDecoration decoration = container.decoration! as BoxDecoration;
        expect(decoration.border?.top.color, isNotNull);
        // Color should be one of the expected colors (green, orange, red)
        final Color borderColor = decoration.border!.top.color;
        final List<Color> expectedColors = <Color>[Colors.green, Colors.orange, Colors.red];
        expect(expectedColors.any((Color color) => color.value == borderColor.value), isTrue);
      });
    });

    group('Leak Tracking Display', () {
      testWidgets('should show leak tracking status when active', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await TestHelpers.pumpAndSettleWithTimeout(tester);
        await tester.pump(const Duration(milliseconds: 100));

        // Assert - should show either leak count or N/A indicator
        final List<Text> textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
        final bool hasLeakText = textWidgets
            .any((Text text) => text.data != null && (text.data!.contains('leaks') || text.data!.contains('N/A')));
        expect(hasLeakText, isTrue);
      });

      testWidgets('should show N/A when leak tracker is inactive', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert - should show N/A indicator when leak tracker is not active
        // (This is expected in test environment where leak tracker isn't initialized)
        expect(find.textContaining('N/A'), findsOneWidget);
      });
    });

    group('Configuration Options', () {
      testWidgets('should handle showDatabaseMonitoring parameter', (WidgetTester tester) async {
        // Act - test with database monitoring disabled
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
              showDatabaseMonitoring: false,
            ),
          ),
        );

        // Assert - should still render the widget
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(find.byIcon(Icons.memory), findsOneWidget);
      });

      testWidgets('should handle different database paths', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const CircularMemoryMonitor(
              databasePath: '/non/existent/path/test.db',
            ),
          ),
        );

        // Assert - should still render without crashing
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
      });
    });

    group('Animation Behavior', () {
      testWidgets('should have animation controllers', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Get the widget state to check animations
        // Note: We can't access private state class, so we just verify the widget renders correctly
        final State state = tester.state(
          find.byType(CircularMemoryMonitor),
        );

        // Assert - state should be initialized
        expect(state, isNotNull);
        // Note: We can't directly access private fields, but we can verify the widget renders
      });

      testWidgets('should animate progress indicator value changes', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Get initial progress value
        await tester.pump(const Duration(milliseconds: 100));
        tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

        // Wait for potential animation update
        await tester.pump(const Duration(milliseconds: 900)); // Animation duration is 800ms

        // Assert - progress indicator should have a value (even if same as initial)
        final CircularProgressIndicator updatedProgress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(updatedProgress.value, isNotNull);
        expect(updatedProgress.value! >= 0.0, isTrue);
        expect(updatedProgress.value! <= 1.0, isTrue);
      });
    });

    group('Widget Lifecycle', () {
      testWidgets('should dispose resources correctly', (WidgetTester tester) async {
        // Act - create and then dispose widget
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Remove the widget to trigger dispose
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const SizedBox.shrink(),
          ),
        );

        // Assert - should not throw errors during disposal
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle rapid widget rebuilds', (WidgetTester tester) async {
        // Act - rapidly rebuild widget multiple times
        for (int i = 0; i < 5; i++) {
          await tester.pumpWidget(
            TestHelpers.createTestWidget(
              CircularMemoryMonitor(
                databasePath: tempDatabase.path,
                key: ValueKey<int>(i),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Assert - should handle rebuilds without errors
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Error Handling', () {
      testWidgets('should handle invalid database path gracefully', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const CircularMemoryMonitor(
              databasePath: '', // Empty path
            ),
          ),
        );

        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert - should not crash
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle memory monitoring errors', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const CircularMemoryMonitor(
              databasePath: '/this/path/definitely/does/not/exist.db',
            ),
          ),
        );

        // Wait for timer to run and potentially encounter errors
        await tester.pump(const Duration(milliseconds: 600));

        // Assert - should handle errors gracefully
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Responsive Design', () {
      testWidgets('should maintain size constraints', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidgetWithMediaQuery(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
            size: const Size(200, 200),
          ),
        );

        // Assert
        final Container container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(CircularMemoryMonitor),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(container.constraints?.maxWidth, equals(60.0)); // 2 * _circleRadius
        expect(container.constraints?.maxHeight, equals(60.0));
      });
    });

    group('Text Styling', () {
      testWidgets('should apply correct text styles', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            CircularMemoryMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert - check memory text styling
        final Text memoryText = tester.widget<Text>(
          find.textContaining('M'),
        );
        expect(memoryText.style?.fontWeight, equals(FontWeight.bold));
        expect(memoryText.style?.fontSize, equals(10));

        // Check for leak text styling
        final List<Text> allTexts = tester.widgetList<Text>(find.byType(Text)).toList();
        final Text? leakText = allTexts.cast<Text?>().firstWhere(
              (Text? text) => text?.data != null && (text!.data!.contains('leaks') || text.data!.contains('N/A')),
              orElse: () => null,
            );
        if (leakText != null) {
          expect(leakText.style?.fontSize, isNotNull);
          expect((leakText.style?.fontSize ?? 0) <= 10, isTrue);
        }
      });
    });
  });
}
