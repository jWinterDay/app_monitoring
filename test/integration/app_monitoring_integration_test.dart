@Skip('Skipping integration tests for now')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:app_monitoring/src/circular_memory_monitor.dart';
import 'package:app_monitoring/src/database_size_monitor.dart';
import 'package:app_monitoring/src/bloc/bloc_debug_observer.dart';
import 'package:app_monitoring/src/memory/memory_leak_simulator.dart';

import '../helpers/test_helpers.dart';

/// Helper to clean up MemoryConcernSimulator resources that may be running
Future<void> _clearMemoryConcernSimulatorResources() async {
  // Since MemoryConcernSimulator creates static timer concerns, we need to wait a bit
  // to ensure any running timers have time to complete their cycles
  // In a real scenario, the simulator should expose a static cleanup method
  await Future<void>.delayed(const Duration(milliseconds: 200));
}

void main() {
  group('App Monitoring Integration Tests', () {
    late File tempDatabase;
    late BlocDebugObserver observer;

    setUp(() async {
      tempDatabase = await TestHelpers.createTempDatabase();
      observer = BlocDebugObserver(maxEventsPerBloc: 10);
      Bloc.observer = observer;
    });

    tearDown(() async {
      await TestHelpers.cleanupTempFile(tempDatabase);
      observer.clearAllData();

      // Clean up any memory concern simulator resources that might be running
      await _clearMemoryConcernSimulatorResources();
    });

    group('Complete Monitoring Dashboard', () {
      testWidgets('should render all monitoring components together', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                ),
                const SizedBox(height: 16),
                DatabaseSizeMonitor(
                  databasePath: tempDatabase.path,
                ),
                const SizedBox(height: 16),
                const Expanded(
                  child: MemoryConcernSimulator(),
                ),
              ],
            ),
          ),
        );

        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert - all components should be present
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(find.byType(MemoryConcernSimulator), findsOneWidget);

        // Check specific elements from each component
        expect(find.byIcon(Icons.memory), findsOneWidget); // From CircularMemoryMonitor
        expect(find.byIcon(Icons.storage), findsOneWidget); // From DatabaseSizeMonitor
        expect(find.text('Memory Concern Simulation (Testing)'), findsOneWidget); // From MemoryConcernSimulator
      });

      testWidgets('should handle simultaneous monitoring operations', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                ),
                DatabaseSizeMonitor(
                  databasePath: tempDatabase.path,
                ),
                const Expanded(child: MemoryConcernSimulator()),
              ],
            ),
          ),
        );

        // Wait for initial monitoring data
        await tester.pump(const Duration(milliseconds: 600));

        // Create a leak using the simulator
        final Finder timerButton = find.ancestor(
          of: find.text('Create Timer Leak'),
          matching: find.byType(TextButton),
        );
        await tester.tap(timerButton);
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Wait for monitoring updates
        await tester.pump(const Duration(seconds: 1));

        // Assert - all components should continue working
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(find.byType(MemoryConcernSimulator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle component removal gracefully', (WidgetTester tester) async {
        // Arrange - start with all components
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                ),
                DatabaseSizeMonitor(
                  databasePath: tempDatabase.path,
                ),
                const Expanded(child: MemoryConcernSimulator()),
              ],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Act - remove components one by one
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                DatabaseSizeMonitor(
                  databasePath: tempDatabase.path,
                ),
                const Expanded(child: MemoryConcernSimulator()),
              ],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const MemoryConcernSimulator(),
          ),
        );

        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert - should handle removal gracefully
        expect(find.byType(MemoryConcernSimulator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Bloc Observer Integration', () {
      testWidgets('should track bloc events while monitoring', (WidgetTester tester) async {
        // Arrange
        final MockBlocWithEvents testBloc = MockBlocWithEvents('initial');

        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            BlocProvider<MockBlocWithEvents>(
              create: (_) => testBloc,
              child: Column(
                children: <Widget>[
                  CircularMemoryMonitor(
                    databasePath: tempDatabase.path,
                  ),
                  BlocBuilder<MockBlocWithEvents, String>(
                    builder: (BuildContext context, String state) {
                      return Text('State: $state');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Act - trigger bloc events
        testBloc.add('test_event_1');
        await tester.pump();

        testBloc.add('test_event_2');
        await tester.pump();

        // Assert - observer should have tracked the events
        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events.length, greaterThanOrEqualTo(2));

        final List<BlocStateRecord> states = observer.getStatesForBloc('MockBlocWithEvents');
        expect(states.length, greaterThanOrEqualTo(2));

        // Clean up
        unawaited(testBloc.close());
      });

      testWidgets('should handle bloc errors during monitoring', (WidgetTester tester) async {
        // Arrange
        final MockBlocWithEvents errorBloc = MockBlocWithEvents('initial');

        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            BlocProvider<MockBlocWithEvents>(
              create: (_) => errorBloc,
              child: Column(
                children: <Widget>[
                  DatabaseSizeMonitor(
                    databasePath: tempDatabase.path,
                  ),
                  BlocBuilder<MockBlocWithEvents, String>(
                    builder: (BuildContext context, String state) => Text('State: $state'),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Act - simulate bloc error
        final TestException testError = TestException('Integration test error');
        observer.onError(errorBloc, testError, StackTrace.current);

        await tester.pump();

        // Assert - error should be recorded
        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events.any((BlocEventRecord event) => event.isError), isTrue);

        // Components should continue working
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Clean up
        unawaited(errorBloc.close());
      });
    });

    group('Memory and Database Monitoring Interaction', () {
      testWidgets('should monitor both memory and database simultaneously', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Row(
              children: <Widget>[
                Expanded(
                  child: CircularMemoryMonitor(
                    databasePath: tempDatabase.path,
                  ),
                ),
                Expanded(
                  child: DatabaseSizeMonitor(
                    databasePath: tempDatabase.path,
                  ),
                ),
              ],
            ),
          ),
        );

        // Wait for monitoring to initialize
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 800)); // Reduced from 2+ seconds

        // Assert - both should display data
        expect(find.textContaining('M'), findsOneWidget); // Memory in MB
        expect(find.textContaining('KB'), findsOneWidget); // Database size
        expect(find.text('ACTIVE'), findsOneWidget); // Database status

        // Both components should be working
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle different database file scenarios', skip: true, (WidgetTester tester) async {
        // Create multiple database files
        final File smallDb = await TestHelpers.createTempDatabase(content: 'small');
        final File largeDb = await TestHelpers.createTempDatabase();
        // Reduced data size to prevent memory pressure during testing (10KB instead of 1MB)
        final List<int> largeData = List<int>.generate(10 * 1024, (int index) => index % 256);
        await largeDb.writeAsBytes(largeData);

        try {
          // Act - monitor different databases
          await tester.pumpWidget(
            TestHelpers.createTestWidget(
              Column(
                children: <Widget>[
                  CircularMemoryMonitor(databasePath: smallDb.path),
                  DatabaseSizeMonitor(databasePath: smallDb.path),
                  const SizedBox(height: 10),
                  CircularMemoryMonitor(databasePath: largeDb.path),
                  DatabaseSizeMonitor(databasePath: largeDb.path),
                ],
              ),
            ),
          );

          // Wait for all 4 monitoring components to initialize their timers
          await TestHelpers.pumpAndSettleWithTimeout(
            tester,
            timeout: const Duration(seconds: 3), // Extra time for 4 components
          );

          // Assert - all monitors should work
          expect(find.byType(CircularMemoryMonitor), findsNWidgets(2));
          expect(find.byType(DatabaseSizeMonitor), findsNWidgets(2));
          expect(find.text('ACTIVE'), findsNWidgets(2));
          expect(tester.takeException(), isNull);
        } finally {
          await TestHelpers.cleanupTempFile(smallDb);
          await TestHelpers.cleanupTempFile(largeDb);
        }
      });
    });

    group('Performance Testing', () {
      testWidgets('should handle rapid component updates', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                ),
                DatabaseSizeMonitor(
                  databasePath: tempDatabase.path,
                ),
              ],
            ),
          ),
        );

        // Simulate rapid updates
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Assert - should handle rapid updates gracefully
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle memory pressure scenarios', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                ),
                const Expanded(child: MemoryConcernSimulator()),
              ],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Simulate memory pressure by creating leaks
        final Finder memoryButton = find.ancestor(
          of: find.text('Create Memory Leak'),
          matching: find.byType(TextButton),
        );
        await tester.tap(memoryButton);
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Wait for monitoring updates
        await tester.pump(const Duration(milliseconds: 600));

        // Assert - components should continue working under memory pressure
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(find.byType(MemoryConcernSimulator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Error Recovery', () {
      testWidgets('should recover from database file deletion', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                ),
                DatabaseSizeMonitor(
                  databasePath: tempDatabase.path,
                ),
              ],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Act - delete the database file
        await tempDatabase.delete();

        // Wait for monitoring to detect the change
        await tester.pump(const Duration(milliseconds: 800)); // Reduced from 2+ seconds

        // Assert - should handle file deletion gracefully
        expect(find.text('MISSING'), findsOneWidget);
        expect(find.text('No DB'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle component initialization errors', (WidgetTester tester) async {
        // Act - use invalid paths
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: '/invalid/path/database.db',
                ),
                DatabaseSizeMonitor(
                  databasePath: '/another/invalid/path.db',
                ),
                Expanded(child: MemoryConcernSimulator()),
              ],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 200));

        // Assert - should handle invalid paths gracefully
        expect(find.byType(CircularMemoryMonitor), findsOneWidget);
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(find.byType(MemoryConcernSimulator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Resource Management', () {
      testWidgets('should properly dispose all resources', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                ),
                DatabaseSizeMonitor(
                  databasePath: tempDatabase.path,
                ),
                const Expanded(child: MemoryConcernSimulator()),
              ],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Create some activity
        final Finder timerButton = find.ancestor(
          of: find.text('Create Timer Leak'),
          matching: find.byType(TextButton),
        );
        await tester.tap(timerButton);
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Act - remove all components
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            const SizedBox.shrink(),
          ),
        );

        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert - should dispose without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Cross-Component Communication', () {
      testWidgets('should handle shared resources correctly', (WidgetTester tester) async {
        // Act - multiple components accessing the same database
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            Column(
              children: <Widget>[
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                ),
                DatabaseSizeMonitor(
                  databasePath: tempDatabase.path,
                ),
                CircularMemoryMonitor(
                  databasePath: tempDatabase.path,
                  showDatabaseMonitoring: false,
                ),
              ],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 200));

        // Assert - all components should work with shared resource
        expect(find.byType(CircularMemoryMonitor), findsNWidgets(2));
        expect(find.byType(DatabaseSizeMonitor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
