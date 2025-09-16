import 'package:app_monitoring/app_monitoring.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

/// Circular debug overlay service that displays CPU and memory monitors above all widgets
/// Follows TRIZ principles: SEGMENTATION (separate overlay system),
/// PRIOR COUNTERACTION (handles context loss), SELF-SERVICE (auto-manages lifecycle)
class CircularDebugOverlay {
  /// Factory constructor that returns the singleton instance
  factory CircularDebugOverlay() => _instance ??= CircularDebugOverlay._();
  CircularDebugOverlay._();
  static CircularDebugOverlay? _instance;

  OverlaySupportEntry? _overlayEntry;
  bool _isShowing = false;

  /// Show circular debug widgets as overlay if debug tools are enabled
  void showOverlayIfEnabled(BuildContext context, {required bool showDebugTools, required String databasePath}) {
    if (!showDebugTools) {
      return;
    }

    if (_isShowing) {
      return;
    }

    _showOverlay(databasePath: databasePath);
  }

  /// Hide the overlay
  void hideOverlay() {
    if (_overlayEntry != null && _isShowing) {
      _overlayEntry!.dismiss();
      _overlayEntry = null;
      _isShowing = false;
    }
  }

  void _showOverlay({required String databasePath}) {
    _overlayEntry = showOverlay(
      (BuildContext context, double t) {
        return Opacity(
          opacity: t,
          child: CircularDebugWidgets(databasePath: databasePath),
        );
      },
      duration: Duration.zero, // Keep visible indefinitely
    );
    _isShowing = true;
  }

  /// Check if overlay should be shown and update accordingly
  void updateOverlayVisibility(BuildContext context, {required bool showDebugTools, required String databasePath}) {
    if (showDebugTools && !_isShowing) {
      _showOverlay(databasePath: databasePath);
    } else if (!showDebugTools && _isShowing) {
      hideOverlay();
    }
  }
}

/// The actual overlay widget containing draggable circular debug monitors
class CircularDebugWidgets extends StatefulWidget {
  const CircularDebugWidgets({super.key, required this.databasePath});
  final String databasePath;

  @override
  State<CircularDebugWidgets> createState() => _CircularDebugWidgetsState();
}

class _CircularDebugWidgetsState extends State<CircularDebugWidgets> {
  Offset _groupOffset = Offset.zero;
  bool _isBottomSheetOpen = false;
  bool _hasInitialPositionBeenSet = false;

  // Relative positions of widgets within the group
  static const Offset _cpuRelativeOffset = Offset.zero; // CPU at top
  static const Offset _memoryRelativeOffset = Offset(0, 80); // Memory 80px below CPU
  static const double _groupHeight = 140.0; // Total height for 2 widgets

  void _showMonitoringBottomSheet(BuildContext context) {
    // Prevent opening multiple bottom sheets
    if (_isBottomSheetOpen) return;

    setState(() {
      _isBottomSheetOpen = true;
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.assessment, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Performance Monitoring',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: <Widget>[
                      const AnimatedCpuProfiler(),
                      const AnimatedMemoryMonitor(),
                      DatabaseSizeMonitor(databasePath: widget.databasePath),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // Reset the flag when bottom sheet is closed
      if (mounted) {
        setState(() {
          _isBottomSheetOpen = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only set the initial position once, don't reset when keyboard opens/closes
    if (!_hasInitialPositionBeenSet) {
      final Size size = MediaQuery.of(context).size;

      // Position the group on the right side, centered vertically
      _groupOffset = Offset(
        size.width - 80, // 80px from right edge (adjusted for smaller widgets)
        (size.height - _groupHeight) * 0.4, // Centered taking total group height into account
      );
      _hasInitialPositionBeenSet = true;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _groupOffset += details.delta;

      // Keep group within screen bounds considering both widgets (60px width for 30px radius)
      final Size size = MediaQuery.of(context).size;
      _groupOffset = Offset(
        _groupOffset.dx.clamp(0.0, size.width - 60), // Account for widget width (30px radius = 60px diameter)
        _groupOffset.dy.clamp(0.0, size.height - _groupHeight - 20), // Account for both widgets height
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            // Group background indicator (subtle visual connection)
            Positioned(
              left: _groupOffset.dx - 4,
              top: _groupOffset.dy - 4,
              child: Container(
                width: 68, // Slightly larger than widget width (60)
                height: _groupHeight + 8, // Height to cover both widgets
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(34),
                ),
              ),
            ),

            // CPU Profiler with tap and drag
            Positioned(
              left: _groupOffset.dx + _cpuRelativeOffset.dx,
              top: _groupOffset.dy + _cpuRelativeOffset.dy,
              child: GestureDetector(
                onTap: () => _showMonitoringBottomSheet(context),
                onPanUpdate: _handlePanUpdate,
                child: const CircularCpuProfiler(),
              ),
            ),

            // Memory Monitor with tap and drag
            Positioned(
              left: _groupOffset.dx + _memoryRelativeOffset.dx,
              top: _groupOffset.dy + _memoryRelativeOffset.dy,
              child: GestureDetector(
                onTap: () => _showMonitoringBottomSheet(context),
                onPanUpdate: _handlePanUpdate,
                child: CircularMemoryMonitor(
                  databasePath: widget.databasePath,
                  showDatabaseMonitoring: false, // Disable individual bottom sheet
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
