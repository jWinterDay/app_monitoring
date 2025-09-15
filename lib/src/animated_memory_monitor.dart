import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:leak_tracker/leak_tracker.dart';

import 'memory_graph_painter.dart';

/// Real-time animated memory monitor widget
/// Follows TRIZ principles: SEGMENTATION (separate widget),
/// LOCAL QUALITY (optimized animations), PRIOR COUNTERACTION (error handling)
class AnimatedMemoryMonitor extends StatefulWidget {
  const AnimatedMemoryMonitor({super.key});

  @override
  State<AnimatedMemoryMonitor> createState() => _AnimatedMemoryMonitorState();
}

class _AnimatedMemoryMonitorState extends State<AnimatedMemoryMonitor> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _memoryAnimation;

  Timer? _memoryTimer;
  double _currentMemoryMB = 0.0;
  double _maxMemoryMB = 0.0;
  double _previousMemoryMB = 0.0;
  final List<double> _memoryHistory = <double>[];

  // Leak tracking integration - Applies TRIZ SEGMENTATION: Professional leak detection
  int _totalLeaks = 0;
  final List<bool> _leakHistory = <bool>[]; // Track leak events for graph visualization
  bool _leakTrackerActive = false;

  static const int _maxHistoryLength = 50;
  static const Duration _updateInterval = Duration(milliseconds: 500);
  static const double _maxExpectedMemoryMB = 2000.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeLeakTracking();
    _startMemoryMonitoring();
  }

  void _initializeAnimations() {
    // Main memory animation controller - Faster for better UX
    // Applies TRIZ SEGMENTATION: Separate quick updates from smooth visuals
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Reduced from 800ms for faster response
      vsync: this,
    );

    // Pulse animation for memory spikes
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
  }

  /// Initialize leak tracking for professional memory leak detection
  /// Applies TRIZ UNIVERSALITY: Industry-standard leak detection across contexts
  void _initializeLeakTracking() {
    try {
      // Check if leak tracking is started and available
      _leakTrackerActive = LeakTracking.isStarted;
      debugPrint('🔍 Leak tracking status: ${_leakTrackerActive ? "ACTIVE" : "INACTIVE"}');

      if (_leakTrackerActive) {
        // Get initial leak count using checkLeaks API
        _checkInitialLeaks();
      } else {
        _totalLeaks = 0;
      }
    } on Exception catch (e) {
      debugPrint('⚠️ Leak tracking initialization error: $e');
      _leakTrackerActive = false;
    }
  }

  /// Check initial leaks at startup
  Future<void> _checkInitialLeaks() async {
    try {
      final LeakSummary summary = await LeakTracking.checkLeaks();
      // Access the actual properties of LeakSummary
      _totalLeaks = summary.total; // Using 'total' instead of 'totalLeaks'
      debugPrint('🔍 Initial leak count: $_totalLeaks (via leak_tracker API)');
    } on Exception catch (e) {
      debugPrint('⚠️ Initial leak check error: $e');
      _totalLeaks = 0;
    }
  }

  void _startMemoryMonitoring() {
    _memoryTimer = Timer.periodic(_updateInterval, (Timer timer) {
      _updateMemoryUsage();
    });

    // Initialize first reading
    _updateMemoryUsage();
  }

  void _updateMemoryUsage() {
    if (!mounted) return;

    try {
      // Get current memory usage (RSS - Resident Set Size)
      final int currentRss = ProcessInfo.currentRss;
      final int maxRss = ProcessInfo.maxRss;

      final double currentMB = currentRss / (1024 * 1024);
      final double maxMB = maxRss / (1024 * 1024);

      // Check for new memory leaks - Applies TRIZ PRIOR COUNTERACTION: Early leak detection
      final bool hasNewLeaks = _checkForNewLeaks();

      setState(() {
        _previousMemoryMB = _currentMemoryMB;
        _currentMemoryMB = currentMB;
        _maxMemoryMB = maxMB;

        // Add to history for graph including leak events
        // Applies TRIZ SEGMENTATION: Separate but synchronized memory and leak data
        _memoryHistory.add(currentMB);
        _leakHistory.add(hasNewLeaks);
        if (_memoryHistory.length > _maxHistoryLength) {
          _memoryHistory.removeAt(0);
          _leakHistory.removeAt(0);
        }

        // Animate memory bar - Fixed to use actual peak memory ratio
        // Applies TRIZ LOCAL QUALITY: Accurate relative visualization
        final double memoryRatio = _maxMemoryMB > 0 ? (_currentMemoryMB / _maxMemoryMB).clamp(0.0, 1.0) : 0.0;
        _animationController.animateTo(memoryRatio);

        // Trigger pulse animation for significant memory increases or new leaks
        if (_currentMemoryMB > _previousMemoryMB + 5 || hasNewLeaks) {
          _pulseController.reset();
          _pulseController.forward();
        }
      });

      // Log for debugging (following profiling template) with leak tracking information
      // Enhanced logging to help debug calculation discrepancies and memory leaks
      final double actualRatio = maxMB > 0 ? (currentMB / maxMB) : 0.0;
      developer.Timeline.instantSync(
        'memory_reading',
        arguments: <dynamic, dynamic>{
          'current_mb': currentMB.toStringAsFixed(1),
          'max_mb': maxMB.toStringAsFixed(1),
          'calculated_ratio': (actualRatio * 100).toStringAsFixed(1),
          'animation_target': ((_currentMemoryMB / _maxMemoryMB) * 100).toStringAsFixed(1),
          'total_leaks': _totalLeaks,
          'new_leaks': hasNewLeaks,
          'leak_tracker_active': _leakTrackerActive,
        },
      );
    } on Exception catch (e) {
      debugPrint('Memory monitoring error: $e');
    }
  }

  /// Checks for new memory leaks using official leak_tracker API
  /// Applies TRIZ PRIOR COUNTERACTION: Early leak detection prevents memory issues
  bool _checkForNewLeaks() {
    try {
      if (!_leakTrackerActive || !LeakTracking.isStarted) {
        return _fallbackLeakDetection();
      }

      // Use async leak checking - schedule it and use cached results
      _performAsyncLeakCheck();

      return false; // Return immediate status, async results will update UI later
    } on Exception catch (e) {
      debugPrint('⚠️ Leak tracking API error: $e');
      // Fallback to basic pattern detection if API fails
      return _fallbackLeakDetection();
    }
  }

  /// Perform async leak check using the correct API
  Future<void> _performAsyncLeakCheck() async {
    try {
      final LeakSummary summary = await LeakTracking.checkLeaks();
      final int currentLeakCount = summary.total; // Using correct property name

      // Check if we have new leaks since last check
      if (currentLeakCount > _totalLeaks) {
        final int newLeakCount = currentLeakCount - _totalLeaks;
        // debugPrint('🚨 NEW MEMORY LEAKS DETECTED by leak_tracker: $newLeakCount new leaks (total: $currentLeakCount)');

        // Log detailed leak information using real leak_tracker data
        developer.Timeline.instantSync(
          'memory_leak_detected',
          arguments: <dynamic, dynamic>{
            'new_leaks': newLeakCount,
            'total_leaks': currentLeakCount,
            'current_mb': _currentMemoryMB.toStringAsFixed(1),
            'leak_summary': summary.toString(),
            'source': 'leak_tracker_official_api',
          },
        );

        // Update UI with new leak count
        if (mounted) {
          setState(() {
            _totalLeaks = currentLeakCount;
          });
        }
      }
    } on Exception catch (e) {
      debugPrint('⚠️ Async leak check error: $e');
    }
  }

  /// Fallback leak detection using memory growth patterns
  bool _fallbackLeakDetection() {
    if (_memoryHistory.length >= 10) {
      final List<double> recentMemory = _memoryHistory.sublist(_memoryHistory.length - 10);
      final double memoryTrend = recentMemory.last - recentMemory.first;
      final double averageGrowth = memoryTrend / 10;

      final bool suspiciousGrowth = averageGrowth > 1.0 && memoryTrend > 10.0;

      if (suspiciousGrowth && _memoryHistory.length % 20 == 0) {
        _totalLeaks++;
        debugPrint('🚨 FALLBACK: Suspicious memory growth detected: ${memoryTrend.toStringAsFixed(1)}MB');
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with pulse animation
          Row(
            children: <Widget>[
              Icon(
                Icons.memory,
                color: Colors.grey.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Memory Monitor',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              // Official leak tracker indicator - Applies TRIZ LOCAL QUALITY: Critical leak visibility
              if (_leakTrackerActive && LeakTracking.isStarted && _totalLeaks > 0) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade600,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blueGrey.shade800),
                  ),
                  child: Text(
                    'LEAKS: $_totalLeaks',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: (_leakTrackerActive && LeakTracking.isStarted)
                      ? (_totalLeaks > 0 ? Colors.blueGrey.shade700 : Colors.green)
                      : Colors.blueGrey.shade500,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LIVE',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Memory usage display - Preventive overflow fix
          // Applies TRIZ PRIOR COUNTERACTION: Preventing potential overflow
          // Applies SEGMENTATION: Flexible segments for different screen sizes
          Row(
            children: <Widget>[
              // Current memory segment - flexible to prevent overflow
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Current: ',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11, // Slightly smaller to fit better
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${_currentMemoryMB.toStringAsFixed(1)} MB',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getMemoryColor(),
                          fontSize: 12, // Slightly smaller to fit better
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8), // Reduced spacing
              // Max memory segment - flexible to prevent overflow
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Peak: ',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11, // Slightly smaller to fit better
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${_maxMemoryMB.toStringAsFixed(1)} MB',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 12, // Slightly smaller to fit better
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Animated memory bar
          AnimatedBuilder(
            animation: _memoryAnimation,
            builder: (BuildContext context, Widget? child) {
              return Column(
                children: <Widget>[
                  // Memory usage bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: <Widget>[
                        FractionallySizedBox(
                          widthFactor: _memoryAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Colors.green,
                                  if (_memoryAnimation.value > 0.7) Colors.blueGrey.shade400 else Colors.green,
                                  if (_memoryAnimation.value > 0.9)
                                    Colors.blueGrey.shade600
                                  else
                                    Colors.blueGrey.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Percentage indicator - Fixed to show actual calculated ratio, not animated value
                  // Applies TRIZ PRIOR COUNTERACTION: Prevent misleading animation lag
                  Column(
                    children: <Widget>[
                      Text(
                        _maxMemoryMB > 0
                            ? '${((_currentMemoryMB / _maxMemoryMB) * 100).toStringAsFixed(0)}% of peak (${_maxMemoryMB.toStringAsFixed(1)}MB)'
                            : 'Current: ${_currentMemoryMB.toStringAsFixed(1)}MB',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      // Debug info during development to verify calculations
                      if (_maxMemoryMB > 0) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'Debug: ${_currentMemoryMB.toStringAsFixed(1)}MB ÷ ${_maxMemoryMB.toStringAsFixed(1)}MB = ${((_currentMemoryMB / _maxMemoryMB) * 100).toStringAsFixed(1)}% | Bar: ${(_memoryAnimation.value * 100).toStringAsFixed(1)}%',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Memory history with leak tracking
          if (_memoryHistory.isNotEmpty) ...<Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Memory History',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                // Leak tracking legend - professional leak detection indicators
                if (_totalLeaks > 0 || _leakHistory.any((bool leak) => leak)) ...<Widget>[
                  Container(
                    width: 2,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade600,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Memory Leaks',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.blueGrey.shade700,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),

            // Leak tracking statistics
            if (_leakTrackerActive) ...<Widget>[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _totalLeaks > 0 ? Colors.blueGrey.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _totalLeaks > 0 ? Colors.blueGrey.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Leak Tracker: ${_leakTrackerActive && LeakTracking.isStarted ? "ACTIVE" : "INACTIVE"}',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: _totalLeaks > 0 ? Colors.blueGrey.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _leakTrackerActive && LeakTracking.isStarted
                          ? 'Detected Leaks: $_totalLeaks | Method: Official leak_tracker API'
                          : 'Pattern Analysis: $_totalLeaks suspicious | Method: Memory Growth Detection',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 8,
                        color: _totalLeaks > 0 ? Colors.blueGrey.shade600 : Colors.grey.shade600,
                      ),
                    ),
                    if (_totalLeaks > 0) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'Check red triangular markers on graph for leak locations',
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 7,
                          color: Colors.blueGrey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            _buildMemoryGraph(),
          ],
        ],
      ),
    );
  }

  Color _getMemoryColor() {
    // Fixed to use actual peak memory ratio instead of hardcoded expected value
    // Applies TRIZ UNIVERSALITY: Reusable color logic across memory contexts
    if (_maxMemoryMB == 0) return Colors.green; // No peak data yet

    final double percentage = (_currentMemoryMB / _maxMemoryMB).clamp(0.0, 1.0);

    if (percentage > 0.9) return Colors.blueGrey.shade600; // >90% of peak usage
    if (percentage > 0.7) return Colors.blueGrey.shade400; // >70% of peak usage
    return Colors.green; // <70% of peak usage
  }

  Widget _buildMemoryGraph() {
    // Fixed to use actual peak memory for graph scaling with leak tracking visualization
    // Applies TRIZ LOCAL QUALITY: Graph scale matches actual usage patterns with professional leak indicators
    final double graphMaxMemory = _maxMemoryMB > 0
        ? _maxMemoryMB * 1.1 // Add 10% headroom for better visualization
        : _maxExpectedMemoryMB; // Fallback to expected if no peak data

    return SizedBox(
      height: 60,
      child: CustomPaint(
        size: Size.infinite,
        painter: MemoryGraphPainter(
          memoryHistory: _memoryHistory,
          maxMemory: graphMaxMemory,
          primaryColor: Colors.grey.shade700,
          backgroundColor: Colors.grey.shade300,
          // Enhanced with professional leak tracking indicators
          leakHistory: _leakHistory,
          leakColor: Colors.blueGrey.shade600,
        ),
      ),
    );
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
