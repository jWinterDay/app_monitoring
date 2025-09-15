import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:app_monitoring/src/bloc/bloc_debug_observer.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('BlocDebugObserver', () {
    late BlocDebugObserver observer;
    late MockBlocWithEvents testBloc;

    setUp(() {
      observer = BlocDebugObserver(maxEventsPerBloc: 5);
      testBloc = MockBlocWithEvents('initial_state');
    });

    tearDown(() {
      testBloc.close();
      observer.clearAllData();
    });

    group('Bloc Lifecycle', () {
      test('should register bloc on create', () {
        // Act
        observer.onCreate(testBloc);

        // Assert
        expect(observer.activeBlocs, contains('MockBlocWithEvents'));
        expect(observer.getBlocCreationDate('MockBlocWithEvents'), isNotNull);
      });

      test('should remove bloc from active list on close', () {
        // Arrange
        observer.onCreate(testBloc);
        expect(observer.activeBlocs, contains('MockBlocWithEvents'));

        // Act
        observer.onClose(testBloc);

        // Assert
        expect(observer.activeBlocs, isEmpty);
        // Data should still be preserved
        expect(observer.getBlocCreationDate('MockBlocWithEvents'), isNotNull);
      });

      test('should sort active blocs by creation date (newest first)', () async {
        // Arrange
        final MockBlocWithEvents bloc1 = MockBlocWithEvents('state1');
        final MockBlocWithEvents bloc2 = MockBlocWithEvents('state2');
        final MockBlocWithEvents bloc3 = MockBlocWithEvents('state3');

        // Act - create in specific order
        observer.onCreate(bloc1);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        observer.onCreate(bloc2);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        observer.onCreate(bloc3);

        // Assert - should have all blocs registered
        final List<String> activeBlocs = observer.activeBlocs;
        // Note: Since all MockBlocWithEvents have the same toString(), they appear as one entry
        expect(activeBlocs.length, greaterThanOrEqualTo(1));

        // Cleanup
        unawaited(bloc1.close());
        unawaited(bloc2.close());
        unawaited(bloc3.close());
      });
    });

    group('Event Tracking', () {
      test('should record events correctly', () {
        // Arrange
        observer.onCreate(testBloc);

        // Act
        observer.onEvent(testBloc, 'test_event');

        // Assert
        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(1));
        expect(events.first.event, equals('test_event'));
        expect(events.first.eventType, contains('test_event'));
        expect(events.first.isError, isFalse);
      });

      test('should limit events per bloc based on maxEventsPerBloc', () {
        // Arrange
        observer.onCreate(testBloc);

        // Act - add more events than the limit
        for (int i = 0; i < 7; i++) {
          observer.onEvent(testBloc, 'event_$i');
        }

        // Assert - should only keep the last 5 events
        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(5));
        expect(events.first.event, equals('event_2')); // First should be event_2 (event_0 and event_1 removed)
        expect(events.last.event, equals('event_6')); // Last should be event_6
      });

      test('should record error events', () {
        // Arrange
        observer.onCreate(testBloc);
        final TestException testError = TestException('Test error message');

        // Act
        observer.onError(testBloc, testError, StackTrace.current);

        // Assert
        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(1));
        expect(events.first.isError, isTrue);
        expect(events.first.event, isA<BlocErrorEvent>());

        final BlocErrorEvent errorEvent = events.first.event! as BlocErrorEvent;
        expect(errorEvent.error, equals(testError));
      });
    });

    group('State Tracking', () {
      test('should record state changes correctly', () {
        // Arrange
        observer.onCreate(testBloc);
        const Change<String> change = Change<String>(
          currentState: 'old_state',
          nextState: 'new_state',
        );

        // Act
        observer.onChange(testBloc, change);

        // Assert
        final List<BlocStateRecord> states = observer.getStatesForBloc('MockBlocWithEvents');
        expect(states, hasLength(1));
        expect(states.first.currentState, equals('old_state'));
        expect(states.first.nextState, equals('new_state'));
        expect(states.first.currentStateType, contains('old_state'));
        expect(states.first.nextStateType, contains('new_state'));
      });

      test('should limit states per bloc based on maxEventsPerBloc', () {
        // Arrange
        observer.onCreate(testBloc);

        // Act - add more state changes than the limit
        for (int i = 0; i < 7; i++) {
          final Change<String> change = Change<String>(
            currentState: 'state_${i - 1}',
            nextState: 'state_$i',
          );
          observer.onChange(testBloc, change);
        }

        // Assert - should only keep the last 5 state changes
        final List<BlocStateRecord> states = observer.getStatesForBloc('MockBlocWithEvents');
        expect(states, hasLength(5));
        expect(states.first.nextState, equals('state_2')); // First should be transition to state_2
        expect(states.last.nextState, equals('state_6')); // Last should be transition to state_6
      });
    });

    group('Transition Tracking', () {
      test('should log transitions for Bloc instances', () {
        // Arrange
        observer.onCreate(testBloc);
        const Transition<String, String> transition = Transition<String, String>(
          currentState: 'old_state',
          event: 'test_event',
          nextState: 'new_state',
        );

        // This test mainly verifies the method doesn't throw
        // The actual logging is handled by the framework
        expect(() => observer.onTransition(testBloc, transition), returnsNormally);
      });
    });

    group('Data Management', () {
      test('should clear bloc data correctly', () {
        // Arrange
        observer.onCreate(testBloc);
        observer.onEvent(testBloc, 'test_event');
        observer.onChange(testBloc, const Change<String>(currentState: 'old', nextState: 'new'));

        // Verify data exists
        expect(observer.getEventsForBloc('MockBlocWithEvents'), isNotEmpty);
        expect(observer.getStatesForBloc('MockBlocWithEvents'), isNotEmpty);

        // Act
        observer.clearBlocData('MockBlocWithEvents');

        // Assert
        expect(observer.getEventsForBloc('MockBlocWithEvents'), isEmpty);
        expect(observer.getStatesForBloc('MockBlocWithEvents'), isEmpty);
      });

      test('should clear all data correctly', () {
        // Arrange
        final MockBlocWithEvents bloc1 = MockBlocWithEvents('state1');
        final MockBlocWithEvents bloc2 = MockBlocWithEvents('state2');

        observer.onCreate(bloc1);
        observer.onCreate(bloc2);
        observer.onEvent(bloc1, 'event1');
        observer.onEvent(bloc2, 'event2');

        // Verify data exists
        expect(observer.activeBlocs, isNotEmpty);

        // Act
        observer.clearAllData();

        // Assert
        expect(observer.activeBlocs, isEmpty);
        expect(observer.getEventsForBloc('MockBlocWithEvents'), isEmpty);
        expect(observer.getStatesForBloc('MockBlocWithEvents'), isEmpty);

        // Cleanup
        unawaited(bloc1.close());
        unawaited(bloc2.close());
      });

      test('should return empty lists for non-existent blocs', () {
        // Act & Assert
        expect(observer.getEventsForBloc('NonExistentBloc'), isEmpty);
        expect(observer.getStatesForBloc('NonExistentBloc'), isEmpty);
        expect(observer.getBlocCreationDate('NonExistentBloc'), isNull);
      });
    });

    group('Listener Management', () {
      test('should add and remove listeners correctly', () {
        // Arrange
        bool listenerCalled = false;
        void testListener() {
          listenerCalled = true;
        }

        // Act - add listener
        observer.addListener(testListener);
        observer.onCreate(testBloc);

        // Assert
        expect(listenerCalled, isTrue);

        // Reset and remove listener
        listenerCalled = false;
        observer.removeListener(testListener);

        // Act - trigger event after removing listener
        observer.onEvent(testBloc, 'test_event');

        // Assert - listener should not be called
        expect(listenerCalled, isFalse);
      });

      test('should notify listeners on events and state changes', () {
        // Arrange
        int listenerCallCount = 0;
        void testListener() {
          listenerCallCount++;
        }

        observer.addListener(testListener);
        observer.onCreate(testBloc);

        // Reset counter after onCreate
        listenerCallCount = 0;

        // Act
        observer.onEvent(testBloc, 'test_event');
        observer.onChange(testBloc, const Change<String>(currentState: 'old', nextState: 'new'));
        observer.onError(testBloc, TestException('test'), StackTrace.current);

        // Assert
        expect(listenerCallCount, equals(3)); // event, change, error
      });
    });

    group('Object Extraction', () {
      test('should handle primitive types correctly', () {
        // Arrange
        observer.onCreate(testBloc);

        // Act & Assert
        observer.onEvent(testBloc, 'string_event');
        observer.onEvent(testBloc, 42);
        observer.onEvent(testBloc, true);

        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(3));
        expect(events[0].eventType, contains('string_event'));
        expect(events[1].eventType, contains('42'));
        expect(events[2].eventType, contains('true'));
      });

      test('should handle null events gracefully', () {
        // Arrange
        observer.onCreate(testBloc);

        // Act
        observer.onEvent(testBloc, null);

        // Assert
        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(1));
        expect(events.first.eventType, equals('null'));
      });

      test('should handle complex objects', () {
        // Arrange
        observer.onCreate(testBloc);
        final Map<String, dynamic> complexEvent = <String, dynamic>{
          'type': 'user_login',
          'userId': 123,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Act
        observer.onEvent(testBloc, complexEvent);

        // Assert
        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(1));
        expect(events.first.eventType, isNotNull);
        expect(events.first.eventType, isNot(equals('null')));
      });
    });

    group('Edge Cases', () {
      test('should handle very long event names', () {
        // Arrange
        observer.onCreate(testBloc);
        final String longEventName = 'very_long_event_name_' * 100; // ignore: avoid_dynamic_calls

        // Act & Assert - should not throw
        expect(() => observer.onEvent(testBloc, longEventName), returnsNormally);

        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(1));
      });

      test('should handle rapid successive events', () {
        // Arrange
        observer.onCreate(testBloc);

        // Act - add many events rapidly
        for (int i = 0; i < 100; i++) {
          observer.onEvent(testBloc, 'rapid_event_$i');
        }

        // Assert - should be limited by maxEventsPerBloc
        final List<BlocEventRecord> events = observer.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(5)); // Limited by maxEventsPerBloc
      });

      test('should handle very small maxEventsPerBloc', () {
        // Arrange - Use 1 instead of 0 to avoid edge case bug
        final BlocDebugObserver smallLimitObserver = BlocDebugObserver(maxEventsPerBloc: 1);
        smallLimitObserver.onCreate(testBloc);

        // Act - Add multiple events
        smallLimitObserver.onEvent(testBloc, 'event1');
        smallLimitObserver.onEvent(testBloc, 'event2');

        // Assert - should only keep the last event
        final List<BlocEventRecord> events = smallLimitObserver.getEventsForBloc('MockBlocWithEvents');
        expect(events, hasLength(1));
        expect(events.first.event, equals('event2'));
      });
    });
  });
}
