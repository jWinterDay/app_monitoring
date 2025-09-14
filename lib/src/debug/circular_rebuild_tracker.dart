import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

/// Circular rebuild tracker overlay widget (30px radius)
/// Tracks Flutter widget rebuilds to detect unnecessary rebuilds
/// Follows TRIZ principles: SEGMENTATION (separate rebuild tracking),
/// LOCAL QUALITY (optimized rebuild detection), PRIOR COUNTERACTION (performance monitoring)
class CircularRebuildTracker extends StatefulWidget {
  const CircularRebuildTracker({super.key});

  @override
  State<CircularRebuildTracker> createState() => _CircularRebuildTrackerState();
}

class _CircularRebuildTrackerState extends State<CircularRebuildTracker> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _flashController;
  late Animation<double> _rebuildAnimation;
  late Animation<double> _flashAnimation;

  Timer? _resetTimer;
  int _rebuildCount = 0;
  int _totalRebuilds = 0;
  int _rebuildsPerSecond = 0;

  static const Duration _resetInterval = Duration(seconds: 1);
  static const double _circleRadius = 30.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startRebuildTracking();
  }

  void _initializeAnimations() {
    // Main rebuild animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Flash animation for rebuilds
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _rebuildAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    _flashAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(
      CurvedAnimation(
        parent: _flashController,
        curve: Curves.elasticOut,
      ),
    );

    // Add listeners to trigger setState when animations change
    _rebuildAnimation.addListener(() {
      if (mounted) setState(() {});
    });

    _flashAnimation.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startRebuildTracking() {
    _resetTimer = Timer.periodic(_resetInterval, (Timer timer) {
      setState(() {
        _rebuildsPerSecond = _rebuildCount;
        _rebuildCount = 0;

        // Animate based on rebuild frequency
        final double intensity = (_rebuildsPerSecond / 60.0).clamp(0.0, 1.0); // Max 60 rebuilds/sec
        _animationController.animateTo(intensity);
      });
    });
  }

  void _trackRebuild() {
    _rebuildCount++;
    _totalRebuilds++;

    // Flash animation for visual feedback
    _flashController.reset();
    _flashController.forward();

    // Log for debugging
    developer.Timeline.instantSync(
      'widget_rebuild',
      arguments: <dynamic, dynamic>{
        'rebuilds_per_second': _rebuildsPerSecond,
        'total_rebuilds': _totalRebuilds,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Track this build - this is the key functionality!
    _trackRebuild();

    final TextTheme textTheme = Theme.of(context).textTheme;

    return Transform.scale(
      scale: _flashAnimation.value,
      child: Container(
        width: _circleRadius * 2,
        height: _circleRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.95),
          border: Border.all(
            color: _getRebuildColor(),
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
            // Circular progress indicator showing rebuild intensity
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: _rebuildAnimation.value,
                strokeWidth: 3,
                backgroundColor: Colors.grey.shade300.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(_getRebuildColor()),
              ),
            ),
            // Center content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.refresh,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  Text(
                    '$_rebuildsPerSecond/s',
                    style: textTheme.bodySmall?.copyWith(
                      color: _getRebuildColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            // Total rebuilds indicator (small badge)
            if (_totalRebuilds > 0) ...<Widget>[
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getRebuildColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _totalRebuilds > 999 ? '999+' : '$_totalRebuilds',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRebuildColor() {
    // Color based on rebuilds per second
    if (_rebuildsPerSecond > 30) return Colors.red; // Red: Too many rebuilds
    if (_rebuildsPerSecond > 15) return Colors.orange; // Orange: Moderate rebuilds
    if (_rebuildsPerSecond > 5) return Colors.blue; // Blue: Some rebuilds
    return Colors.green; // Green: Few rebuilds
  }

  @override
  void dispose() {
    // SELF-SERVICE: Proper resource cleanup
    _resetTimer?.cancel();
    _animationController.dispose();
    _flashController.dispose();
    super.dispose();
  }
}
