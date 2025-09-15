import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_monitoring/src/database_size_monitor.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('DatabaseSizeMonitor Widget', () {
    late File tempDatabase;
    late File largeTempDatabase;

    setUp(() async {
      // Create temporary database files for testing
      tempDatabase = await TestHelpers.createTempDatabase();

      // Create a larger database for size testing
      final List<int> largeData = List<int>.generate(1024 * 1024, (int index) => index % 256); // 1MB
      largeTempDatabase = await TestHelpers.createTempDatabase();
      await largeTempDatabase.writeAsBytes(largeData);
    });

    tearDown(() async {
      // Clean up temporary files
      await TestHelpers.cleanupTempFile(tempDatabase);
      await TestHelpers.cleanupTempFile(largeTempDatabase);
    });

    group('Widget Creation and Display', () {
      testWidgets('should render without errors', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Assert
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(find.byIcon(Icons.storage), findsOneWidget);
      });

      testWidgets('should display all required UI elements', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Wait for initial size reading
        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        expect(find.byIcon(Icons.storage), findsOneWidget);
        expect(find.text('Database Size'), findsOneWidget);
        expect(find.textContaining('ACTIVE'), findsOneWidget);
        expect(find.textContaining('KB'), findsOneWidget);
      });

      testWidgets('should have correct container styling', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Assert
        final Container container = tester.widget<Container>(
          find.byType(Container).first,
        );

        expect(container.decoration, isA<BoxDecoration>());
        final BoxDecoration decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, equals(Colors.grey.shade100));
        expect(decoration.borderRadius, equals(BorderRadius.circular(8)));
        expect(decoration.border, isNotNull);
      });
    });

    group('File Size Display', () {
      testWidgets('should display file size for existing database', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Wait for file size to be read
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('KB'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);

        // Icon should be green for existing database
        final Icon icon = tester.widget<Icon>(find.byIcon(Icons.storage));
        expect(icon.color, equals(Colors.green));
      });

      testWidgets('should display correct size format for large files', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: largeTempDatabase.path,
            ),
          ),
        );

        // Wait for file size to be read
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Assert - should display MB for large files
        expect(find.textContaining('MB'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
      });

      testWidgets('should update size periodically', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Get initial size
        await tester.pump(const Duration(milliseconds: 100));

        // Wait for timer update (timer runs every 2 seconds)
        await tester.pump(const Duration(seconds: 2, milliseconds: 100));

        // Assert - should still display size (might be same value)
        final String updatedSizeText = tester.widget<Text>(find.textContaining('KB')).data!;
        expect(updatedSizeText, matches(RegExp(r'\d+\.?\d*KB')));
      });

      testWidgets('should format small sizes correctly', skip: true, (WidgetTester tester) async {
        // Create a very small database
        final File smallDb = await TestHelpers.createTempDatabase(content: 'small');

        try {
          // Act
          await tester.pumpWidget(
            TestHelpers.createTestWidget(
              DatabaseSizeMonitor(
                databasePath: smallDb.path,
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 100));

          // Assert - should display in KB for small files
          expect(find.textContaining('KB'), findsOneWidget);
        } finally {
          await TestHelpers.cleanupTempFile(smallDb);
        }
      });
    });

    group('Non-existent Database Handling', () {
      testWidgets('should handle non-existent database gracefully', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const DatabaseSizeMonitor(
              databasePath: '/path/that/does/not/exist.db',
            ),
          ),
        );

        // Wait for initial check
        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        expect(find.text('No DB'), findsOneWidget);
        expect(find.text('MISSING'), findsOneWidget);

        // Icon should be grey for missing database
        final Icon icon = tester.widget<Icon>(find.byIcon(Icons.storage));
        expect(icon.color, equals(Colors.grey.shade600));
      });

      testWidgets('should display unknown.db for invalid paths', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const DatabaseSizeMonitor(
              databasePath: '/invalid/path.db',
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Assert - should show unknown.db when path extraction fails
        expect(find.textContaining('unknown.db'), findsOneWidget);
      });
    });

    group('Database Name Display', () {
      testWidgets('should extract and display database name from path', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Assert - should display the actual database filename
        final String expectedName = tempDatabase.path.split('/').last;
        expect(find.textContaining(expectedName), findsOneWidget);
      });

      testWidgets('should handle complex database paths', (WidgetTester tester) async {
        const String complexPath = '/complex/path/with/subdirs/test_database.sqlite';

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const DatabaseSizeMonitor(
              databasePath: complexPath,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        expect(find.textContaining('test_database.sqlite'), findsOneWidget);
      });
    });

    group('Timestamp Display', () {
      testWidgets('should display last updated timestamp', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Assert - should show timestamp in HH:MM:SS format
        final List<Text> textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
        final bool hasTimestamp =
            textWidgets.any((Text text) => text.data != null && RegExp(r'\d{2}:\d{2}:\d{2}').hasMatch(text.data!));
        expect(hasTimestamp, isTrue);
      });

      testWidgets('should update timestamp on refresh', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Get initial timestamp
        await tester.pump(const Duration(milliseconds: 100));
        final List<Text> initialTextWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
        initialTextWidgets.map((Text text) => text.data).firstWhere(
              (String? data) => data != null && RegExp(r'\d{2}:\d{2}:\d{2}').hasMatch(data),
              orElse: () => null,
            );

        // Wait for update
        await tester.pump(const Duration(seconds: 2, milliseconds: 100));

        // Assert - timestamp should be present (might be different)
        final List<Text> updatedTextWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
        final bool hasUpdatedTimestamp = updatedTextWidgets
            .any((Text text) => text.data != null && RegExp(r'\d{2}:\d{2}:\d{2}').hasMatch(text.data!));
        expect(hasUpdatedTimestamp, isTrue);
      });
    });

    group('Text Styling', () {
      testWidgets('should apply correct text styles', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Assert - check title styling
        final Text titleText = tester.widget<Text>(find.text('Database Size'));
        expect(titleText.style?.color, equals(Colors.grey.shade600));
        expect(titleText.style?.fontSize, equals(12));

        // Check size text styling
        final Text sizeText = tester.widget<Text>(find.textContaining('KB'));
        expect(sizeText.style?.fontWeight, equals(FontWeight.bold));
        expect(sizeText.style?.fontSize, equals(14));
      });

      testWidgets('should style ACTIVE badge correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        final Container badge = tester.widget<Container>(
          find.ancestor(
            of: find.text('ACTIVE'),
            matching: find.byType(Container),
          ),
        );

        final BoxDecoration? decoration = badge.decoration as BoxDecoration?;
        expect(decoration?.color, equals(Colors.green));
        expect(decoration?.borderRadius, equals(BorderRadius.circular(3)));
      });

      testWidgets('should style MISSING badge correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const DatabaseSizeMonitor(
              databasePath: '/non/existent/path.db',
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        final Container badge = tester.widget<Container>(
          find.ancestor(
            of: find.text('MISSING'),
            matching: find.byType(Container),
          ),
        );

        final BoxDecoration? decoration = badge.decoration as BoxDecoration?;
        expect(decoration?.color, equals(Colors.grey.shade600));
      });
    });

    group('Widget Lifecycle', () {
      testWidgets('should dispose timer correctly', (WidgetTester tester) async {
        // Act - create and then dispose widget
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
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
    });

    group('Error Handling', () {
      testWidgets('should handle file read errors gracefully', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const DatabaseSizeMonitor(
              databasePath: '', // Invalid path
            ),
          ),
        );

        // Wait for error handling
        await tester.pump(const Duration(milliseconds: 100));

        // Assert - should not crash
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle permission errors', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const DatabaseSizeMonitor(
              databasePath: '/root/restricted/database.db', // Likely no permission
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 200));

        // Assert - should handle gracefully
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Layout and Responsive Design', () {
      testWidgets('should layout elements correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Assert - should have Row as main layout
        expect(find.byType(Row), findsOneWidget);

        // Should have Expanded widget for main content
        expect(find.byType(Expanded), findsOneWidget);

        // Should have Column for right-side info
        expect(find.byType(Column), findsWidgets);
      });

      testWidgets('should maintain margins and padding', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
          ),
        );

        // Assert
        final Container mainContainer = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(mainContainer.margin, equals(const EdgeInsets.symmetric(vertical: 4)));
        expect(mainContainer.padding, equals(const EdgeInsets.all(12)));
      });

      testWidgets('should work in different screen sizes', (WidgetTester tester) async {
        // Test small screen
        await tester.pumpWidget(
          TestHelpers.createTestWidgetWithMediaQuery(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
            size: const Size(200, 400),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);

        // Test large screen
        await tester.pumpWidget(
          TestHelpers.createTestWidgetWithMediaQuery(
            DatabaseSizeMonitor(
              databasePath: tempDatabase.path,
            ),
            size: const Size(800, 600),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
      });
    });

    group('Size Formatting', () {
      testWidgets('should format bytes correctly', (WidgetTester tester) async {
        // Create databases of different sizes to test formatting
        final File tinyDb = await TestHelpers.createTempDatabase(content: 'a'); // Very small
        final File smallDb = await TestHelpers.createTempDatabase(content: 'a' * 500); // 500 bytes

        try {
          // Test tiny file
          await tester.pumpWidget(
            TestHelpers.createTestWidget(
              DatabaseSizeMonitor(
                databasePath: tinyDb.path,
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 100));
          expect(find.textContaining('KB'), findsOneWidget);

          // Test small file
          await tester.pumpWidget(
            TestHelpers.createTestWidget(
              DatabaseSizeMonitor(
                databasePath: smallDb.path,
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 100));
          expect(find.textContaining('KB'), findsOneWidget);
        } finally {
          await TestHelpers.cleanupTempFile(tinyDb);
          await TestHelpers.cleanupTempFile(smallDb);
        }
      });
    });
  });
}
