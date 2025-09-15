import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:leak_tracker/leak_tracker.dart';

class CircularMemoryMonitor extends StatefulWidget {
  const CircularMemoryMonitor({
    required this.databasePath,
    this.showDatabaseMonitoring = true,
    super.key,
  });
  final String databasePath;
  final bool showDatabaseMonitoring;

  @override
  State<CircularMemoryMonitor> createState() => _CircularMemoryMonitorState();
}

class _CircularMemoryMonitorState extends State<CircularMemoryMonitor> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _memoryAnimation;
  late Animation<double> _pulseAnimation;

  Timer? _memoryTimer;
  double _currentMemoryMB = 0.0;
  double _previousMemoryMB = 0.0;

  // Leak tracking integration - Applies TRIZ SEGMENTATION: Professional leak detection
  int _totalLeaks = 0;
  bool _leakTrackerActive = false;

  static const Duration _updateInterval = Duration(milliseconds: 500);
  static const double _maxExpectedMemoryMB = 2000.0;
  static const double _circleRadius = 30.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeLeakTracking();
    _startMemoryMonitoring();
  }

  void _initializeAnimations() {
    // Main memory animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Pulse animation for memory spikes
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _memoryAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.elasticOut,
      ),
    );

    // Add listeners to trigger setState when animations change
    _memoryAnimation.addListener(() {
      if (mounted) setState(() {});
    });

    _pulseAnimation.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startMemoryMonitoring() {
    _memoryTimer = Timer.periodic(_updateInterval, (Timer timer) {
      _updateMemoryUsage();
    });

    // Initialize first reading
    _updateMemoryUsage();
  }

  /// Initialize leak tracking for professional memory leak detection
  /// Applies TRIZ UNIVERSALITY: Industry-standard leak detection across contexts
  void _initializeLeakTracking() {
    try {
      // Check if leak tracking is started and available
      _leakTrackerActive = LeakTracking.isStarted;
      debugPrint('🔍 Circular Memory Monitor - Leak tracking status: ${_leakTrackerActive ? "ACTIVE" : "INACTIVE"}');

      if (_leakTrackerActive) {
        // Get initial leak count using checkLeaks API
        _checkInitialLeaks();
      } else {
        _totalLeaks = 0;
      }
    } on Exception catch (e) {
      debugPrint('⚠️ Circular Memory Monitor - Leak tracking initialization error: $e');
      _leakTrackerActive = false;
    }
  }

  /// Check initial leaks at startup
  Future<void> _checkInitialLeaks() async {
    try {
      final LeakSummary summary = await LeakTracking.checkLeaks();
      _totalLeaks = summary.total;
      debugPrint('🔍 Circular Memory Monitor - Initial leak count: $_totalLeaks');
    } on Exception catch (e) {
      debugPrint('⚠️ Circular Memory Monitor - Initial leak check error: $e');
      _totalLeaks = 0;
    }
  }

  /// Perform async leak check using the correct API
  /// COORDINATION FIX: Use only checkLeaks() to avoid interfering with RealTimeMemoryMonitor
  /// which uses collectLeaks() and consumes/clears the leaked objects
  Future<void> _performAsyncLeakCheck() async {
    try {
      if (!_leakTrackerActive || !LeakTracking.isStarted) {
        return;
      }

      // Use ONLY checkLeaks() for non-destructive monitoring
      // This prevents interference with RealTimeMemoryMonitor's collectLeaks() calls
      final LeakSummary summary = await LeakTracking.checkLeaks();
      final int currentLeakCount = summary.total;

      // Update leak count - coordinated with other leak monitors
      if (currentLeakCount != _totalLeaks) {
        if (mounted) {
          setState(() {
            _totalLeaks = currentLeakCount;
          });
        }

        // Enhanced logging for coordination debugging
        debugPrint('🔍 Circular Monitor - Leak count updated: $_totalLeaks (non-destructive check)');
      }
    } on Exception catch (e) {
      debugPrint('⚠️ Circular Memory Monitor - Async leak check error: $e');
    }
  }

  void _updateMemoryUsage() {
    if (!mounted) return;

    try {
      // Get current memory usage (RSS - Resident Set Size)
      final int currentRss = ProcessInfo.currentRss;
      final int maxRss = ProcessInfo.maxRss;

      final double currentMB = currentRss / (1024 * 1024);
      final double maxMB = maxRss / (1024 * 1024);

      setState(() {
        _previousMemoryMB = _currentMemoryMB;
        _currentMemoryMB = currentMB;

        // Animate memory circle - Fixed to use actual system memory ratio
        // Note: CircularMemoryMonitor doesn't track maxRss, so we use a reasonable approach
        // Could be enhanced to show system-wide memory context
        _animationController.animateTo(
          (_currentMemoryMB / _maxExpectedMemoryMB).clamp(0.0, 1.0),
        );

        // Trigger pulse animation for significant memory increases
        if (_currentMemoryMB > _previousMemoryMB + 10) {
          _pulseController.reset();
          _pulseController.forward();
        }
      });

      // Check for leaks periodically - Applies TRIZ PRIOR COUNTERACTION: Early leak detection
      if (_leakTrackerActive) {
        _performAsyncLeakCheck();
      }

      // Log for debugging
      developer.Timeline.instantSync(
        'circular_memory_reading',
        arguments: <dynamic, dynamic>{
          'current_mb': currentMB.toStringAsFixed(1),
          'max_mb': maxMB.toStringAsFixed(1),
          'total_leaks': _totalLeaks,
          'leak_tracker_active': _leakTrackerActive,
        },
      );
    } on Exception catch (e) {
      debugPrint('Circular memory monitoring error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _circleRadius * 2,
        height: _circleRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.95),
          border: Border.all(
            color: _getMemoryColor(),
            width: 2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            // Circular progress indicator
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: _memoryAnimation.value,
                strokeWidth: 3,
                backgroundColor: Colors.grey.shade300.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(_getMemoryColor()),
              ),
            ),
            // Center content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.memory,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  Text(
                    '${_currentMemoryMB.toStringAsFixed(0)}M',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getMemoryColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                  ),
                  // Leak tracker information - Applies TRIZ LOCAL QUALITY: Compact leak display
                  if (_leakTrackerActive)
                    Text(
                      '$_totalLeaks',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getLeakColor(),
                            fontWeight: FontWeight.w500,
                            fontSize: 8,
                          ),
                    )
                  else
                    Text(
                      '🔍 N/A',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w400,
                            fontSize: 8,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMemoryColor() {
    final double percentage = _currentMemoryMB / _maxExpectedMemoryMB;

    if (percentage > 0.9) return Colors.blueGrey.shade700;
    if (percentage > 0.7) return Colors.blueGrey.shade500;
    return Colors.green;
  }

  /// Get leak indicator color - Applies TRIZ LOCAL QUALITY: Visual leak severity indication
  Color _getLeakColor() {
    if (_totalLeaks == 0) return Colors.green;
    if (_totalLeaks <= 5) return Colors.blueGrey.shade500;
    return Colors.blueGrey.shade700;
  }

  @override
  void dispose() {
    // SELF-SERVICE: Proper resource cleanup
    _memoryTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
