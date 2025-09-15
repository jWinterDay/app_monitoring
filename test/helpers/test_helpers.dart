import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Test helper class for creating mock data and utilities
class TestHelpers {
  TestHelpers._();

  /// Create a temporary database file for testing
  static Future<File> createTempDatabase({String? content}) async {
    final Directory tempDir = Directory.systemTemp;
    final File tempFile = File('${tempDir.path}/test_db_${DateTime.now().millisecondsSinceEpoch}.db');

    if (content != null) {
      await tempFile.writeAsString(content);
    } else {
      // Create a mock database file with some sample data
      final List<int> mockData = List<int>.generate(1024, (int index) => index % 256); // 1KB of data
      await tempFile.writeAsBytes(mockData);
    }

    return tempFile;
  }

  /// Clean up temporary files
  static Future<void> cleanupTempFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception catch (e) {
      // Ignore cleanup errors in tests
      debugPrint('Failed to cleanup temp file: $e');
    }
  }

  /// Create a test widget wrapped with necessary providers
  static Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  /// Create a test widget with MediaQuery for responsive testing
  static Widget createTestWidgetWithMediaQuery(
    Widget child, {
    Size size = const Size(400, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: child,
        ),
      ),
    );
  }

  /// Pump and settle with a custom duration for animations
  static Future<void> pumpAndSettleWithTimeout(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final DateTime startTime = DateTime.now();

    while (tester.binding.hasScheduledFrame) {
      await tester.pump(const Duration(milliseconds: 100));

      final Duration elapsed = DateTime.now().difference(startTime);
      if (elapsed > timeout) {
        throw TimeoutException('pumpAndSettle exceeded timeout', timeout);
      }
    }
  }

  /// Wait for a condition to be true with timeout
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    final DateTime startTime = DateTime.now();

    while (!condition()) {
      final Duration elapsed = DateTime.now().difference(startTime);
      if (elapsed > timeout) {
        throw TimeoutException('Condition not met within timeout', timeout);
      }

      await Future<void>.delayed(checkInterval);
    }
  }
}

/// Mock BlocBase for testing BlocDebugObserver
class MockBloc extends BlocBase<String> {
  MockBloc(super.initialState);

  void emitState(String state) => emit(state);

  void addEvent(String event) {
    // Simulate event processing
    emitState('processed_$event');
  }
}

/// Mock Bloc with events for testing
class MockBlocWithEvents extends Bloc<String, String> {
  MockBlocWithEvents(super.initialState) {
    on<String>((String event, Emitter<String> emit) {
      emit('processed_$event');
    });
  }
}

/// Custom exception for testing error handling
class TestException implements Exception {
  TestException(this.message);

  final String message;

  @override
  String toString() => 'TestException: $message';
}

/// Mock TickerProvider for animation testing
class TestTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}

/// Utility class for memory testing
class MemoryTestUtils {
  MemoryTestUtils._();

  /// Create a list of objects that consume memory
  static List<List<int>> createMemoryConsumingObjects(int count, int sizePerObject) {
    return List<List<int>>.generate(count, (int index) => List<int>.filled(sizePerObject, index));
  }

  /// Get approximate memory usage of an object
  static int getApproximateMemoryUsage(dynamic object) {
    if (object is List) {
      return object.length * 8; // Approximate 8 bytes per item
    } else if (object is String) {
      return object.length * 2; // Approximate 2 bytes per character
    } else if (object is Map) {
      return object.length * 16; // Approximate 16 bytes per key-value pair
    }
    return 8; // Default size for simple objects
  }
}

/// Timeout exception for async operations
class TimeoutException implements Exception {
  const TimeoutException(this.message, this.timeout);

  final String message;
  final Duration timeout;

  @override
  String toString() => '$message (timeout: ${timeout.inMilliseconds}ms)';
}
