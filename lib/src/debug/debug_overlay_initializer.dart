import 'package:app_monitoring/app_monitoring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Initializes debug overlay after first frame
/// Follows TRIZ principles: SELF-SERVICE (auto-initialization),
/// PRIOR COUNTERACTION (handles context availability)
class DebugOverlayInitializer extends StatefulWidget {
  const DebugOverlayInitializer({
    required this.child,
    required this.showDebugTools,
    required this.databasePath,
    super.key,
  });

  final Widget child;
  final bool showDebugTools;
  final String databasePath;

  @override
  State<DebugOverlayInitializer> createState() => _DebugOverlayInitializerState();
}

class _DebugOverlayInitializerState extends State<DebugOverlayInitializer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize overlay after first frame when context is fully available
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_initialized) {
        _initialized = true;
        CircularDebugOverlay().showOverlayIfEnabled(
          context,
          showDebugTools: widget.showDebugTools,
          databasePath: widget.databasePath,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
