// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'leakable_widgets.dart';

/// Memory leak simulator widget for testing leak detection
/// UNIVERSALITY (multiple leak types), PRIOR COUNTERACTION (controlled testing)
class MemoryLeakSimulator extends StatefulWidget {
  const MemoryLeakSimulator({super.key});

  @override
  State<MemoryLeakSimulator> createState() => _MemoryLeakSimulatorState();
}

class _MemoryLeakSimulatorState extends State<MemoryLeakSimulator> {
  // Static collections to simulate leaks that persist beyond widget lifecycle
  static final List<Timer> _leakedTimers = <Timer>[];
  static final List<StreamSubscription<dynamic>> _leakedSubscriptions = <StreamSubscription<dynamic>>[];
  static final List<Widget> _leakedWidgets = <Widget>[];
  static final List<List<int>> _leakedMemoryChunks = <List<int>>[];
  static final Map<String, dynamic> _leakedObjects = <String, dynamic>{};

  // Track widgets actually added to tree for leak detection
  final List<Widget> _activeLeakableWidgets = <Widget>[];
  bool _showLeakableWidgets = false;

  @override
  void dispose() {
    // Intentionally NOT cleaning up to demonstrate leaks
    // In real code, you should always clean up resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Memory Leak Simulation (Testing)',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.purple.withValues(alpha: 0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '📋 Instructions for testing leak detection:',
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1. Click "Create Widget Leak" or "Create Memory Leak"',
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: Colors.purple.shade600,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '2. Widgets will appear below (this makes them trackable)',
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: Colors.purple.shade600,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '3. Click "Hide Widgets" to trigger dispose() and create leaks',
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: Colors.purple.shade600,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '4. Check the real-time leak monitor above for detected leaks! 🔍',
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: Colors.purple.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Timer Leak Simulation
              _buildLeakButton(
                context,
                'Create Timer Leak',
                Icons.timer,
                Colors.red,
                _createTimerLeak,
                'Creates uncancelled timers that will persist',
              ),

              // Stream Subscription Leak
              _buildLeakButton(
                context,
                'Create Stream Leak',
                Icons.stream,
                Colors.orange,
                _createStreamLeak,
                'Creates unsubscribed stream subscriptions',
              ),

              // Widget Reference Leak
              _buildLeakButton(
                context,
                'Create Widget Leak',
                Icons.widgets,
                Colors.blue,
                _createWidgetLeak,
                'Keeps references to disposed widgets',
              ),

              // Memory Chunk Leak
              _buildLeakButton(
                context,
                'Create Memory Leak',
                Icons.memory,
                Colors.green,
                _createMemoryLeak,
                'Allocates memory that grows continuously',
              ),

              // Multiple Leaks
              _buildLeakButton(
                context,
                'Create Multiple Leaks',
                Icons.bug_report,
                Colors.purple,
                _createMultipleLeaks,
                'Creates several different types of leaks',
              ),

              const SizedBox(height: 8),

              // Current leak counts
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Simulated Leaks:',
                      style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Timers: ${_leakedTimers.length}, Streams: ${_leakedSubscriptions.length}, '
                      'Widgets: ${_leakedWidgets.length}, Memory: ${_leakedMemoryChunks.length}MB, '
                      'Objects: ${_leakedObjects.length}',
                      style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Clear all leaks button
              TextButton.icon(
                onPressed: _clearAllLeaks,
                icon: const Icon(Icons.cleaning_services, size: 16),
                label: const Text('Clear All Simulated Leaks'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  alignment: Alignment.centerLeft,
                ),
              ),

              // Show actual leakable widgets for testing
              if (_showLeakableWidgets) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.red.withValues(alpha: 0.05),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Active Leakable Widgets (for leak_tracker detection):',
                        style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._activeLeakableWidgets,
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _hideLeakableWidgets,
                        icon: const Icon(Icons.visibility_off, size: 14),
                        label: const Text('Hide Widgets (Trigger Dispose)'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeakButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    String description,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16, color: color),
              label: Text(
                label,
                style: (textTheme.bodySmall ?? const TextStyle()).copyWith(color: color),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
          Tooltip(
            message: description,
            child: Icon(
              Icons.info_outline,
              size: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _createTimerLeak() {
    // Create timers that are never cancelled - classic timer leak
    for (int i = 0; i < 3; i++) {
      final Timer timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        // Simulate some work that keeps references alive
        final List<int> data = List<int>.generate(1000, (int index) => index);
        developer.log('Timer leak $i tick: ${data.length} items');
      });
      _leakedTimers.add(timer);
    }

    _showLeakCreatedMessage('Created 3 timer leaks (not tracked by leak_tracker)');
  }

  void _createStreamLeak() {
    // Create stream subscriptions that are never cancelled
    for (int i = 0; i < 2; i++) {
      final StreamController<int> controller = StreamController<int>.broadcast();
      final StreamSubscription<int> subscription = controller.stream.listen((int value) {
        // Keep some data alive
        final Map<String, dynamic> data = <String, dynamic>{
          'timestamp': DateTime.now(),
          'value': value,
          'data': List<int>.filled(500, value),
        };
        developer.log('Stream leak $i: $data');
      });

      _leakedSubscriptions.add(subscription);

      // Keep adding data to the stream
      Timer.periodic(const Duration(seconds: 2), (Timer t) {
        if (!controller.isClosed) {
          controller.add(DateTime.now().millisecondsSinceEpoch);
        }
      });
    }

    _showLeakCreatedMessage('Created 2 stream subscription leaks (not tracked by leak_tracker)');
  }

  void _createWidgetLeak() {
    // Create actual Flutter widget leaks that leak_tracker can detect
    _activeLeakableWidgets.clear();

    for (int i = 0; i < 3; i++) {
      // Create StatefulWidgets with keys that we'll keep references to
      final GlobalKey<LeakableWidgetState> key = GlobalKey<LeakableWidgetState>();
      final Widget leakedWidget = LeakableWidget(
        key: key,
        id: i,
        onDisposed: (int id) {
          developer.log('LeakableWidget $id disposed but we keep controller references');
        },
      );

      // Add to active widgets so they get rendered
      _activeLeakableWidgets.add(leakedWidget);

      // Also add to static list (old behavior)
      _leakedWidgets.add(leakedWidget);

      // Keep the GlobalKey reference which prevents GC of the widget
      _leakedObjects['widget_key_$i'] = key;
    }

    // Show the widgets in UI so they get built by Flutter framework
    setState(() {
      _showLeakableWidgets = true;
    });

    _showLeakCreatedMessage('Created 3 Flutter widget leaks - widgets are now active. Hide them to trigger leaks.');
  }

  void _createMemoryLeak() {
    // Create Flutter widgets with controllers and add widgets that use them to tree
    _activeLeakableWidgets.clear();

    for (int i = 0; i < 2; i++) {
      // Create TextEditingControllers and other disposable Flutter objects
      final TextEditingController controller = TextEditingController(text: 'Leak test $i');
      final ScrollController scrollController = ScrollController();
      final AnimationController animController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: LeakableTickerProvider(),
      );

      // Keep references to prevent proper disposal
      _leakedObjects['text_controller_$i'] = controller;
      _leakedObjects['scroll_controller_$i'] = scrollController;
      _leakedObjects['anim_controller_$i'] = animController;

      // Create widgets that actually use these controllers
      final Widget controllerWidget = Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 40,
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Controller Leak Test $i',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 40,
              child: ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                itemBuilder: (BuildContext context, int index) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$index', style: const TextStyle(fontSize: 10)),
                ),
              ),
            ),
          ],
        ),
      );

      _activeLeakableWidgets.add(controllerWidget);

      // Create memory chunks for traditional memory leaks
      final List<int> memoryChunk = List<int>.filled(250000, i); // ~1MB per chunk
      _leakedMemoryChunks.add(memoryChunk);
    }

    // Show the widgets so they get built and controllers get tracked
    setState(() {
      _showLeakableWidgets = true;
    });

    _showLeakCreatedMessage('Created controller leaks + memory. Widgets are active - hide them to trigger leaks.');
  }

  void _createMultipleLeaks() {
    // Create a combination of different leak types
    _createTimerLeak();
    _createStreamLeak();
    _createWidgetLeak();
    _createMemoryLeak();

    _showLeakCreatedMessage('Created multiple types of leaks for comprehensive testing');
  }

  void _hideLeakableWidgets() {
    // Hide the widgets to trigger dispose() but keep references to create leaks
    setState(() {
      _showLeakableWidgets = false;
      _activeLeakableWidgets.clear();
    });

    // Wait a moment for dispose to be called, then check for leaks
    Timer(const Duration(seconds: 2), () {
      _showLeakCreatedMessage('Widgets hidden and disposed - check leak monitor above for detected leaks! 🔍');
    });

    developer.log('LeakSimulator: Widgets hidden, dispose() should be called but references are kept');
  }

  void _clearAllLeaks() {
    // Clean up all simulated leaks
    for (final Timer timer in _leakedTimers) {
      timer.cancel();
    }
    _leakedTimers.clear();

    for (final StreamSubscription<dynamic> subscription in _leakedSubscriptions) {
      subscription.cancel();
    }
    _leakedSubscriptions.clear();

    // Dispose Flutter controllers properly
    for (final dynamic obj in _leakedObjects.values) {
      if (obj is TextEditingController) {
        obj.dispose();
      } else if (obj is ScrollController) {
        obj.dispose();
      } else if (obj is AnimationController) {
        obj.dispose();
      }
    }

    _leakedWidgets.clear();
    _leakedMemoryChunks.clear();
    _leakedObjects.clear();

    // Clear active widgets too
    setState(() {
      _activeLeakableWidgets.clear();
      _showLeakableWidgets = false;
    });

    if (mounted) {
      _showLeakCreatedMessage('All simulated leaks cleared ✅');
    }
  }

  void _showLeakCreatedMessage(String message) {
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(Icons.bug_report, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.purple.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
