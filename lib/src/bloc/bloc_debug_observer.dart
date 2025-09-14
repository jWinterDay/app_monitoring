import 'dart:collection';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Utility methods for extracting meaningful information from objects, especially freezed models
class _ObjectExtractor {
  _ObjectExtractor._();

  /// Extract meaningful information from objects, especially freezed models
  static String? extractObjectInfo(Object? obj) {
    if (obj == null) return null;

    try {
      final String typeName = obj.runtimeType.toString();

      // Check if it's a simple type that can be displayed directly
      if (obj is String || obj is num || obj is bool) {
        return '$typeName: $obj';
      }

      // Handle special case for error events
      if (obj.runtimeType.toString() == 'BlocErrorEvent') {
        return 'BlocErrorEvent: ${(obj as dynamic).error.runtimeType}';
      }

      // For complex objects, try to extract meaningful information
      final String stringRep = obj.toString();
      if (stringRep != "Instance of '$typeName'" && !stringRep.startsWith("Instance of '")) {
        // Check if it looks like a freezed model (common patterns like EventName(...) or StateName(...))
        final bool looksLikeFreezedModel = _isLikelyFreezedModel(stringRep);

        if (looksLikeFreezedModel && stringRep.length <= 200) {
          // For freezed models, prioritize the full toString() even if it's longer
          return stringRep;
        } else if (stringRep.length <= 150) {
          // For other meaningful toString() implementations
          return stringRep;
        } else {
          // For very long strings, try to extract key information but preserve class name
          final String extracted = _extractKeyFields(stringRep);
          return extracted.isNotEmpty ? extracted : typeName;
        }
      }

      // Fallback: just show the type name
      return typeName;
    } on Exception catch (e) {
      log('Error extracting object info: $e', name: 'BlocObserver');
      // Safe fallback if any extraction fails
      return obj.runtimeType.toString();
    }
  }

  /// Extract key fields from object string representation
  static String _extractKeyFields(String objString) {
    try {
      // Look for patterns like "ClassName(field1: value1, field2: value2)" or freezed patterns
      final RegExp pattern = RegExp(r'(\w+):\s*([^,)}\]]+)');
      final Iterable<RegExpMatch> matches = pattern.allMatches(objString);

      final List<String> fields = <String>[];
      int count = 0;

      for (final RegExpMatch match in matches) {
        if (match.groupCount >= 2 && count < 3) {
          // Limit to 3 key fields
          final String key = match.group(1)!;
          final String value = match.group(2)!.trim();
          fields.add('$key: $value');
          count++;
        }
      }

      if (fields.isNotEmpty) {
        final String className = _extractClassName(objString);
        final String fieldsStr = fields.join(', ');
        // Always try to include class name, even if extraction fails
        if (className.isNotEmpty) {
          return '$className($fieldsStr)';
        } else {
          // If we can't extract class name, try to find it in the original string
          final String fallbackClassName = _findClassNameInString(objString);
          return fallbackClassName.isNotEmpty ? '$fallbackClassName($fieldsStr)' : fieldsStr;
        }
      }
    } on Exception catch (e) {
      log('Error extracting key fields: $e', name: 'BlocObserver');
      // If parsing fails, return empty
    }

    return '';
  }

  /// Extract class name from object string
  static String _extractClassName(String objString) {
    try {
      // Look for patterns like "ClassName(" at the beginning
      final RegExp classPattern = RegExp(r'^(\w+)\(');
      final RegExpMatch? match = classPattern.firstMatch(objString);
      return match?.group(1) ?? '';
    } on Exception catch (e) {
      log('Error extracting class name: $e', name: 'BlocObserver');
      return '';
    }
  }

  /// Find class name in string using multiple patterns (fallback method)
  static String _findClassNameInString(String objString) {
    try {
      // Try multiple patterns for class name extraction
      final List<RegExp> patterns = <RegExp>[
        // Standard pattern: ClassName(...)
        RegExp(r'^(\w+)\('),
        // Pattern with spaces: ClassName (...)
        RegExp(r'^(\w+)\s*\('),
        // Pattern for event names: HomeEventSomething, AuthEventSomething, etc.
        RegExp(r'^(\w*Event\w*)\('),
        // Pattern for state names: HomeStateSomething, AuthStateSomething, etc.
        RegExp(r'^(\w*State\w*)\('),
        // General pattern for camelCase class names
        RegExp(r'^([A-Z]\w*[A-Z]\w*)\('),
      ];

      for (final RegExp pattern in patterns) {
        final RegExpMatch? match = pattern.firstMatch(objString);
        if (match != null && match.group(1) != null) {
          final String className = match.group(1)!;
          // Make sure we found a meaningful class name (not just single letter)
          if (className.length > 2) {
            return className;
          }
        }
      }
    } on Exception catch (e) {
      log('Error finding class name in string: $e', name: 'BlocObserver');
    }

    return '';
  }

  /// Check if a string representation looks like a freezed model
  static bool _isLikelyFreezedModel(String stringRep) {
    try {
      // Freezed models typically have patterns like:
      // - ClassName(field: value, field2: value2)
      // - EventNameSomething(parameters...)
      // - StateNameSomething(parameters...)
      final List<RegExp> freezedPatterns = <RegExp>[
        // Event patterns
        RegExp(r'^[A-Z]\w*Event[A-Z]\w*\(.*\)$'),
        // State patterns
        RegExp(r'^[A-Z]\w*State[A-Z]\w*\(.*\)$'),
        // General pattern: CamelCaseClassName(field: value, ...)
        RegExp(r'^[A-Z][a-z]+[A-Z]\w*\(\w+:\s*[^,)]+.*\)$'),
        // Pattern for classes ending with common freezed suffixes
        RegExp(r'^[A-Z]\w*(Event|State|Data|Model|Entity|Request|Response)\(.*\)$'),
      ];

      return freezedPatterns.any((RegExp pattern) => pattern.hasMatch(stringRep));
    } on Exception catch (e) {
      log('Error checking if likely freezed model: $e', name: 'BlocObserver');
      return false;
    }
  }
}

/// A custom BlocObserver that captures and stores bloc events and states
/// for debugging and visualization purposes.
///
/// Applies TRIZ PRIOR COUNTERACTION: Prevents performance issues by limiting stored events
/// and SEGMENTATION: Separates concerns between observation and visualization
class BlocDebugObserver extends BlocObserver {
  BlocDebugObserver({this.maxEventsPerBloc = 100});

  final int maxEventsPerBloc;

  // Storage for bloc events and states - using queues for efficient memory management
  final Map<String, Queue<BlocEventRecord>> _blocEvents = <String, Queue<BlocEventRecord>>{};
  final Map<String, Queue<BlocStateRecord>> _blocStates = <String, Queue<BlocStateRecord>>{};

  // Active blocs registry for filtering
  final Set<String> _activeBlocs = <String>{};

  // Bloc creation dates for sorting and display
  final Map<String, DateTime> _blocCreationDates = <String, DateTime>{};

  // Listeners for real-time updates
  final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Get all recorded events for a specific bloc
  List<BlocEventRecord> getEventsForBloc(String blocName) {
    return _blocEvents[blocName]?.toList() ?? <BlocEventRecord>[];
  }

  /// Get all recorded states for a specific bloc
  List<BlocStateRecord> getStatesForBloc(String blocName) {
    return _blocStates[blocName]?.toList() ?? <BlocStateRecord>[];
  }

  /// Get list of all active bloc names sorted by creation date (newest first)
  List<String> get activeBlocs {
    final List<String> blocs = _activeBlocs.toList();
    blocs.sort((String a, String b) {
      final DateTime? dateA = _blocCreationDates[a];
      final DateTime? dateB = _blocCreationDates[b];
      if (dateA == null && dateB == null) return a.compareTo(b);
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // Newest first (descending)
    });
    return blocs;
  }

  /// Get creation date for a specific bloc
  DateTime? getBlocCreationDate(String blocName) {
    return _blocCreationDates[blocName];
  }

  /// Add listener for real-time updates
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Clear all recorded data for a specific bloc
  void clearBlocData(String blocName) {
    _blocEvents[blocName]?.clear();
    _blocStates[blocName]?.clear();
    _notifyListeners();
  }

  /// Clear all recorded data
  void clearAllData() {
    _blocEvents.clear();
    _blocStates.clear();
    _activeBlocs.clear();
    _blocCreationDates.clear();
    _notifyListeners();
  }

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    final String blocName = _getBlocName(bloc);
    final DateTime now = DateTime.now();

    _activeBlocs.add(blocName);
    _blocCreationDates[blocName] = now;

    log('🏗️ Bloc created: $blocName at ${now.toIso8601String()}', name: 'BlocObserver');
    _notifyListeners();
  }

  @override
  void onEvent(BlocBase<dynamic> bloc, Object? event) {
    // Call super only for Bloc instances, not Cubit instances
    if (bloc is Bloc<dynamic, dynamic>) {
      super.onEvent(bloc, event);
    }
    final String blocName = _getBlocName(bloc);
    final BlocEventRecord record = BlocEventRecord(
      blocName: blocName,
      event: event,
      timestamp: DateTime.now(),
    );

    _addEventRecord(blocName, record);

    log('📨 Event: $blocName -> ${event.runtimeType}', name: 'BlocObserver');
    _notifyListeners();
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);

    final String blocName = _getBlocName(bloc);
    final BlocStateRecord record = BlocStateRecord(
      blocName: blocName,
      currentState: change.currentState,
      nextState: change.nextState,
      timestamp: DateTime.now(),
    );

    _addStateRecord(blocName, record);

    log(
      '🔄 State: $blocName -> ${change.currentState.runtimeType} -> ${change.nextState.runtimeType}',
      name: 'BlocObserver',
    );
    _notifyListeners();
  }

  @override
  void onTransition(BlocBase<dynamic> bloc, Transition<dynamic, dynamic> transition) {
    // Call super only for Bloc instances, not Cubit instances
    if (bloc is Bloc<dynamic, dynamic>) {
      super.onTransition(bloc, transition);
    }
    final String blocName = _getBlocName(bloc);
    log(
      '🔀 Transition: $blocName -> ${transition.event.runtimeType} -> ${transition.nextState.runtimeType}',
      name: 'BlocObserver',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);

    final String blocName = _getBlocName(bloc);
    final BlocEventRecord errorRecord = BlocEventRecord(
      blocName: blocName,
      event: BlocErrorEvent(error: error, stackTrace: stackTrace),
      timestamp: DateTime.now(),
    );

    _addEventRecord(blocName, errorRecord);

    log('❌ Error: $blocName -> $error', name: 'BlocObserver');
    _notifyListeners();
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    final String blocName = _getBlocName(bloc);

    log('🗑️ Bloc closed: $blocName', name: 'BlocObserver');
    // Keep the data but mark as inactive
    _activeBlocs.remove(blocName);
    _notifyListeners();
  }

  /// Extract a human-readable name from the bloc instance
  String _getBlocName(BlocBase<dynamic> bloc) {
    return bloc.runtimeType.toString();
  }

  /// Add event record with memory management
  void _addEventRecord(String blocName, BlocEventRecord record) {
    _blocEvents.putIfAbsent(blocName, Queue<BlocEventRecord>.new);
    final Queue<BlocEventRecord> events = _blocEvents[blocName]!;

    // Apply TRIZ PRIOR COUNTERACTION: Prevent memory issues by limiting stored events
    if (events.length >= maxEventsPerBloc) {
      events.removeFirst(); // Remove oldest event
    }

    events.addLast(record);
  }

  /// Add state record with memory management
  void _addStateRecord(String blocName, BlocStateRecord record) {
    _blocStates.putIfAbsent(blocName, Queue<BlocStateRecord>.new);
    final Queue<BlocStateRecord> states = _blocStates[blocName]!;

    // Apply TRIZ PRIOR COUNTERACTION: Prevent memory issues by limiting stored states
    if (states.length >= maxEventsPerBloc) {
      states.removeFirst(); // Remove oldest state
    }

    states.addLast(record);
  }

  /// Notify all listeners of changes
  void _notifyListeners() {
    for (final VoidCallback listener in _listeners) {
      listener();
    }
  }
}

/// Record of a bloc event
class BlocEventRecord {
  const BlocEventRecord({
    required this.blocName,
    required this.event,
    required this.timestamp,
  });

  final String blocName;
  final Object? event;
  final DateTime timestamp;

  String get eventType => _ObjectExtractor.extractObjectInfo(event) ?? 'null';

  bool get isError => event is BlocErrorEvent;
}

/// Record of a bloc state change
class BlocStateRecord {
  const BlocStateRecord({
    required this.blocName,
    required this.currentState,
    required this.nextState,
    required this.timestamp,
  });

  final String blocName;
  final dynamic currentState;
  final dynamic nextState;
  final DateTime timestamp;

  String get currentStateType => _ObjectExtractor.extractObjectInfo(currentState) ?? 'null';
  String get nextStateType => _ObjectExtractor.extractObjectInfo(nextState) ?? 'null';
}

/// Special event type for errors
class BlocErrorEvent {
  const BlocErrorEvent({
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;
}
