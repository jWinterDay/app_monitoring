@Skip('Skipping memory concern simulator tests for now')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_monitoring/src/memory/memory_leak_simulator.dart';

import '../helpers/test_helpers.dart';

// Helper function to find buttons by their text label
Finder findButtonByText(String text) {
  final Finder textFinder = find.text(text);
  return find.ancestor(
    of: textFinder,
    matching: find.byType(InkWell),
  );
}

void main() {
  group('MemoryConcernSimulator Widget', () {
    group('Widget Creation and Display', () {
      testWidgets('should render without errors', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert
        expect(find.byType(MemoryConcernSimulator), findsOneWidget);
        expect(find.text('Memory Concern Simulation (Testing)'), findsOneWidget);
      });

      testWidgets('should display all required UI components', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert
        expect(find.text('Memory Concern Simulation (Testing)'), findsOneWidget);
        expect(find.text('📋 Instructions for testing memory monitoring:'), findsOneWidget);
        expect(find.text('Create Timer Concern'), findsOneWidget);
        expect(find.text('Create Stream Concern'), findsOneWidget);
        expect(find.text('Create Widget Concern'), findsOneWidget);
        expect(find.text('Create Memory Concern'), findsOneWidget);
        expect(find.text('Create Multiple Concerns'), findsOneWidget);
        expect(find.text('Clear All Simulated Concerns'), findsOneWidget);
      });

      testWidgets('should have correct styling', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert - check main container styling
        final Container mainContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MemoryConcernSimulator),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(mainContainer.decoration, isA<BoxDecoration>());
        final BoxDecoration decoration = mainContainer.decoration! as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(8)));
        expect(decoration.border, isNotNull);
      });
    });

    group('Leak Creation Buttons', () {
      testWidgets('should have all leak creation buttons', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert
        expect(find.byIcon(Icons.timer), findsOneWidget);
        expect(find.byIcon(Icons.stream), findsOneWidget);
        expect(find.byIcon(Icons.widgets), findsOneWidget);
        expect(find.byIcon(Icons.memory), findsOneWidget);
        expect(find.byIcon(Icons.bug_report), findsOneWidget);
      });

      testWidgets('should display button tooltips', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert - check for info icons that indicate tooltips
        expect(find.byIcon(Icons.info_outline), findsWidgets);

        final List<Tooltip> tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip)).toList();
        expect(tooltips.isNotEmpty, isTrue);
      });

      testWidgets('timer leak button should be tappable', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Find the text and then its tappable ancestor (InkWell or GestureDetector)
        final Finder timerText = find.text('Create Timer Concern');
        expect(timerText, findsOneWidget);

        // Find the tappable ancestor - InkWell is what makes the button tappable
        final Finder timerButton = find.ancestor(
          of: timerText,
          matching: find.byType(InkWell),
        );

        // Assert
        expect(timerButton, findsOneWidget);

        // Verify we can tap it without error
        await tester.tap(timerButton);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('stream leak button should be tappable', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Find the text and then its tappable ancestor (InkWell)
        final Finder streamText = find.text('Create Stream Concern');
        expect(streamText, findsOneWidget);

        final Finder streamButton = find.ancestor(
          of: streamText,
          matching: find.byType(InkWell),
        );

        // Assert
        expect(streamButton, findsOneWidget);

        // Verify we can tap it without error
        await tester.tap(streamButton);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('widget leak button should be tappable', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Find the text and then its tappable ancestor (InkWell)
        final Finder widgetText = find.text('Create Widget Concern');
        expect(widgetText, findsOneWidget);

        final Finder widgetButton = find.ancestor(
          of: widgetText,
          matching: find.byType(InkWell),
        );

        // Assert
        expect(widgetButton, findsOneWidget);

        // Verify we can tap it without error
        await tester.tap(widgetButton);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });

    group('Leak Statistics Display', () {
      testWidgets('should display leak statistics', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert
        expect(find.text('Simulated Concerns:'), findsOneWidget);
        expect(find.textContaining('Timers:'), findsOneWidget);
        expect(find.textContaining('Streams:'), findsOneWidget);
        expect(find.textContaining('Widgets:'), findsOneWidget);
        expect(find.textContaining('Memory:'), findsOneWidget);
        expect(find.textContaining('Objects:'), findsOneWidget);
      });

      testWidgets('should show initial zero counts', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert - initial state should show zero leaks
        final String statsText = tester
            .widget<Text>(
              find.textContaining('Timers:'),
            )
            .data!;

        expect(statsText, contains('Timers: 0'));
        expect(statsText, contains('Streams: 0'));
        expect(statsText, contains('Widgets: 0'));
        expect(statsText, contains('Memory: 0'));
        expect(statsText, contains('Objects: 0'));
      });
    });

    group('User Instructions', () {
      testWidgets('should display complete instructions', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert
        expect(find.text('1. Click "Create Widget Concern" or "Create Memory Concern"'), findsOneWidget);
        expect(find.text('2. Widgets will appear below (this makes them trackable)'), findsOneWidget);
        expect(find.text('3. Click "Hide Widgets" to trigger dispose() and create retention issues'), findsOneWidget);
        expect(find.text('4. Check the real-time monitor above for detected concerns! 🔍'), findsOneWidget);
      });

      testWidgets('should style instructions correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert - check instruction text styling
        final Text instructionTitle = tester.widget<Text>(
          find.text('📋 Instructions for testing memory monitoring:'),
        );
        expect(instructionTitle.style?.fontWeight, equals(FontWeight.bold));

        final List<Text> instructionTexts = tester
            .widgetList<Text>(
              find.textContaining(RegExp(r'^\d\.')),
            )
            .toList();
        expect(instructionTexts.isNotEmpty, isTrue);

        for (final Text text in instructionTexts) {
          expect(text.style?.fontSize, equals(11));
        }
      });
    });

    group('Clear Functionality', () {
      testWidgets('should have clear all leaks button', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert
        expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
        expect(find.text('Clear All Simulated Concerns'), findsOneWidget);

        // Find the tappable InkWell ancestor of the clear button
        final Finder clearText = find.text('Clear All Simulated Concerns');
        final Finder clearButton = find.ancestor(
          of: clearText,
          matching: find.byType(InkWell),
        );
        expect(clearButton, findsOneWidget);
      });
    });

    group('Widget Interaction', () {
      testWidgets('should tap timer leak button without error', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        final Finder timerButton = findButtonByText('Create Timer Concern');

        // Tap the button
        await tester.tap(timerButton);
        await tester.pump();

        // Assert - should not throw errors
        expect(tester.takeException(), isNull);
        expect(find.byType(MemoryConcernSimulator), findsOneWidget);
      });

      testWidgets('should tap stream leak button without error', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        final Finder streamButton = findButtonByText('Create Stream Concern');

        // Tap the button
        await tester.tap(streamButton);
        await tester.pump();

        // Assert
        expect(tester.takeException(), isNull);
      });

      testWidgets('should tap widget leak button and show widgets', skip: true, (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        final Finder widgetButton = findButtonByText('Create Widget Concern');

        // Tap the button
        await tester.tap(widgetButton);
        await tester.pumpAndSettle();

        // Assert - should show the leakable widgets section
        expect(find.text('Active Leakable Widgets (for memory tracker detection):'), findsOneWidget);
        expect(find.text('Hide Widgets (Trigger Dispose)'), findsOneWidget);
      });

      testWidgets('should tap memory leak button and show widgets', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        final Finder memoryButton = findButtonByText('Create Memory Concern');

        // Tap the button
        await tester.tap(memoryButton);
        await tester.pumpAndSettle();

        // Assert - should show the leakable widgets with controllers
        expect(find.text('Active Leakable Widgets (for memory tracker detection):'), findsOneWidget);
        expect(find.byType(TextField), findsWidgets); // Should show text fields with controllers
      });

      testWidgets('should tap multiple leaks button without error', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        final Finder multipleButton = findButtonByText('Create Multiple Concerns');

        // Tap the button
        await tester.tap(multipleButton);
        await tester.pumpAndSettle();

        // Assert
        expect(tester.takeException(), isNull);
        expect(find.text('Active Leakable Widgets (for memory tracker detection):'), findsOneWidget);
      });

      testWidgets('should tap clear button without error', skip: true, (WidgetTester tester) async {
        // Arrange - first create some leaks
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        final Finder widgetButton = findButtonByText('Create Widget Concern');
        await tester.tap(widgetButton);
        await tester.pumpAndSettle();

        // Act - clear the leaks
        final Finder clearButton = findButtonByText('Clear All Simulated Concerns');
        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        // Assert
        expect(tester.takeException(), isNull);
        // Widgets should be hidden after clearing
        expect(find.text('Active Leakable Widgets (for memory tracker detection):'), findsNothing);
      });
    });

    group('Hide Widgets Functionality', () {
      testWidgets('should show hide button when widgets are active', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Create widget leaks first
        final Finder widgetButton = findButtonByText('Create Widget Concern');
        await tester.tap(widgetButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Hide Widgets (Trigger Dispose)'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      });

      testWidgets('should hide widgets when hide button is tapped', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Create widget leaks
        final Finder widgetButton = findButtonByText('Create Widget Concern');
        await tester.tap(widgetButton);
        await tester.pumpAndSettle();

        // Act - hide widgets
        final Finder hideButton = findButtonByText('Hide Widgets (Trigger Dispose)');
        await tester.tap(hideButton);
        await tester.pumpAndSettle();

        // Assert - widgets should be hidden
        expect(find.text('Active Leakable Widgets (for memory tracker detection):'), findsNothing);
        expect(find.text('Hide Widgets (Trigger Dispose)'), findsNothing);
      });
    });

    group('Widget Styling and Layout', () {
      testWidgets('should have correct column layout', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert
        expect(find.byType(Column), findsWidgets);

        final Column mainColumn = tester.widget<Column>(
          find
              .descendant(
                of: find.byType(MemoryConcernSimulator),
                matching: find.byType(Column),
              )
              .first,
        );
        expect(mainColumn.crossAxisAlignment, equals(CrossAxisAlignment.start));
      });

      testWidgets('should use correct color scheme', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert - check title color
        final Text titleText = tester.widget<Text>(
          find.text('Memory Concern Simulation (Testing)'),
        );
        expect(titleText.style?.color, equals(Colors.purple.shade700));
        expect(titleText.style?.fontWeight, equals(FontWeight.bold));
      });

      testWidgets('should have proper button styling', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert - check that tappable buttons exist by finding InkWell widgets
        final List<InkWell> buttons = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
        expect(buttons.length, greaterThanOrEqualTo(5)); // At least 5 leak buttons + clear button

        // Verify that key button texts are present (which confirms buttons are functional)
        expect(find.text('Create Timer Concern'), findsOneWidget);
        expect(find.text('Create Stream Concern'), findsOneWidget);
        expect(find.text('Create Widget Concern'), findsOneWidget);
        expect(find.text('Create Memory Concern'), findsOneWidget);
        expect(find.text('Create Multiple Concerns'), findsOneWidget);
        expect(find.text('Clear All Simulated Concerns'), findsOneWidget);
      });
    });

    group('Error Handling and Edge Cases', () {
      testWidgets('should handle rapid button taps', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        final Finder timerButton = findButtonByText('Create Timer Concern');

        // Rapidly tap the button multiple times
        for (int i = 0; i < 5; i++) {
          await tester.tap(timerButton);
          await tester.pump(const Duration(milliseconds: 10));
        }

        // Assert - should handle gracefully
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle widget disposal gracefully', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Create some leaks
        final Finder widgetButton = findButtonByText('Create Widget Concern');
        await tester.tap(widgetButton);
        await tester.pumpAndSettle();

        // Remove the widget entirely
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const SizedBox.shrink(),
          ),
        );

        // Assert - should dispose without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Accessibility', () {
      testWidgets('should have accessible button labels', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert - all buttons should have meaningful text
        expect(find.text('Create Timer Concern'), findsOneWidget);
        expect(find.text('Create Stream Concern'), findsOneWidget);
        expect(find.text('Create Widget Concern'), findsOneWidget);
        expect(find.text('Create Memory Concern'), findsOneWidget);
        expect(find.text('Create Multiple Concerns'), findsOneWidget);
        expect(find.text('Clear All Simulated Concerns'), findsOneWidget);
      });

      testWidgets('should have informative tooltips', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        // Assert - should have tooltip widgets
        final List<Tooltip> tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip)).toList();
        expect(tooltips.length, greaterThanOrEqualTo(5)); // One for each leak type

        for (final Tooltip tooltip in tooltips) {
          expect(tooltip.message, isNotNull);
          expect(tooltip.message!.isNotEmpty, isTrue);
        }
      });
    });

    group('Snackbar Notifications', () {
      testWidgets('should show snackbar when creating timer leaks', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        final Finder timerButton = findButtonByText('Create Timer Concern');

        await tester.tap(timerButton);
        await tester.pumpAndSettle();

        // Assert - check for snackbar (though it might not be visible in tests)
        // The method calls ScaffoldMessenger, so we verify no errors occurred
        expect(tester.takeException(), isNull);
      });
    });
  });
}
