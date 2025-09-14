import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Helper widget that can be leaked for testing leak_tracker
/// This creates actual Flutter framework objects that leak_tracker can detect
class LeakableWidget extends StatefulWidget {
  const LeakableWidget({
    super.key,
    required this.id,
    required this.onDisposed,
  });

  final int id;
  final ValueChanged<int> onDisposed;

  @override
  State<LeakableWidget> createState() => LeakableWidgetState();
}

class LeakableWidgetState extends State<LeakableWidget> with TickerProviderStateMixin {
  late TextEditingController _textController;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Create disposable controllers that leak_tracker can monitor
    _textController = TextEditingController(text: 'Leakable widget ${widget.id}');
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    // Start animation to keep the controller active
    _animationController.repeat();
  }

  @override
  void dispose() {
    // Intentionally NOT disposing these to create leaks
    // In real code, you should always dispose controllers:
    // _textController.dispose();
    // _scrollController.dispose();
    // _animationController.dispose();

    widget.onDisposed(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1 + (_animation.value * 0.1)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Leakable Widget ${widget.id}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: 20,
                itemBuilder: (BuildContext context, int index) => ListTile(
                  title: Text('Item $index in widget ${widget.id}'),
                  subtitle: Text('Animation value: ${_animation.value.toStringAsFixed(2)}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ticker provider for creating AnimationController leaks
class LeakableTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}
