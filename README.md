# App Monitoring 📊

A comprehensive Flutter package for real-time app performance monitoring, memory leak detection, and debug tools. Built following TRIZ methodology principles for optimal performance and maintainability.

## ✨ Features

### 🚀 Performance Monitoring
- **Real-time CPU Profiling** - Animated CPU usage monitoring with visual indicators
- **Memory Usage Tracking** - Live memory consumption monitoring with leak detection
- **Database Size Monitoring** - Track SQL database file sizes in real-time
- **Circular Compact Views** - Space-efficient 30px radius monitoring widgets
- **Historical Data Visualization** - Graph painters for performance trends

### 🎯 BLoC State Management Monitoring
- **BLoC Debug Observer** - Capture all BLoC events and state changes
- **Beautiful Visualizer UI** - Material Design interface with filtering capabilities
- **Real-time Updates** - Live monitoring with auto-refresh
- **Search & Filter** - Filter events by name, type, or specific BLoC instances
- **Memory Efficient** - Configurable event limits (default: 100 per BLoC)

### 🔍 Memory Leak Detection
- **Professional Leak Tracking** - Integration with `leak_tracker` package
- **Real-time Monitoring** - Live leak detection every 2 seconds
- **Leak Location Tracking** - Identify exactly where leaks occur in your code
- **Severity Analysis** - Categorize leak severity with recommendations
- **Non-destructive Checking** - Monitor without triggering garbage collection

### 🛠️ Debug Tools & Overlays
- **Circular Debug Overlays** - Compact debug information displays
- **Rebuild Tracking** - Monitor widget rebuild patterns
- **Debug Overlay System** - Comprehensive overlay management
- **Performance Graphs** - Custom painters for CPU and memory visualization

## 📦 Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  app_monitoring:
    path: ./packages/app_monitoring  # Adjust path as needed
```

Or if published:

```yaml
dependencies:
  app_monitoring: ^0.0.1
```

## 🚀 Quick Start

### Basic Usage

```dart
import 'package:app_monitoring/app_monitoring.dart';
import 'package:flutter/material.dart';

void main() {
  // Initialize BLoC monitoring (optional)
  if (kDebugMode) {
    final debugObserver = BlocDebugObserver();
    Bloc.observer = debugObserver;
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('App Monitoring Demo')),
        body: Column(
          children: [
            // Real-time memory monitoring
            AnimatedMemoryMonitor(),
            
            // CPU profiling
            AnimatedCpuProfiler(),
            
            // Database size monitoring
            DatabaseSizeMonitor(
              databasePath: '/path/to/your/database.db',
            ),
            
            // BLoC state visualization
            BlocVisualizer(),
            
            // Memory leak monitoring
            Expanded(
              child: RealTimeLeakMonitor(),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Compact Circular Overlays

For space-constrained UIs, use the circular variants:

```dart
Stack(
  children: [
    YourMainContent(),
    
    // Positioned circular monitors
    Positioned(
      top: 50,
      right: 20,
      child: CircularCpuProfiler(),
    ),
    
    Positioned(
      top: 100,
      right: 20,
      child: CircularMemoryMonitor(
        databasePath: '/path/to/database.db',
      ),
    ),
    
    Positioned(
      top: 150,
      right: 20,
      child: CircularDebugOverlay(),
    ),
  ],
)
```

### Debug Overlay System

Initialize comprehensive debug overlays:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return DebugOverlayInitializer(
          child: child!,
        );
      },
      home: MyHomePage(),
    );
  }
}
```

## 📱 Components

### Performance Monitors

| Component | Description | Size | Features |
|-----------|-------------|------|----------|
| `AnimatedCpuProfiler` | Full-size CPU monitor | Flexible | Real-time graphs, animations |
| `CircularCpuProfiler` | Compact CPU monitor | 30px radius | Color-coded indicators |
| `AnimatedMemoryMonitor` | Full-size memory monitor | Flexible | Leak integration, history |
| `CircularMemoryMonitor` | Compact memory monitor | 30px radius | Pulse animations |
| `DatabaseSizeMonitor` | Database file monitor | Small widget | File size, status |

### BLoC Monitoring

| Component | Description | Features |
|-----------|-------------|----------|
| `BlocDebugObserver` | Core observer | Event capture, memory management |
| `BlocVisualizer` | Visual interface | Filtering, search, real-time updates |

### Memory Leak Detection

| Component | Description | Purpose |
|-----------|-------------|---------|
| `RealTimeLeakMonitor` | Main leak detector | Live monitoring, recommendations |
| `MemoryLeakSimulator` | Testing tool | Simulate leaks for testing |
| `LeakableWidgets` | Test widgets | Create controllable leaks |

### Graph Painters

| Component | Description | Use Case |
|-----------|-------------|----------|
| `CpuGraphPainter` | CPU visualization | Custom CPU graphs |
| `MemoryGraphPainter` | Memory visualization | Custom memory graphs |

## ⚙️ Configuration

### BLoC Observer Configuration

```dart
// Custom event limits
final observer = BlocDebugObserver(maxEventsPerBloc: 200);
Bloc.observer = observer;

// Access monitoring data
final allEvents = observer.getAllEvents();
final specificBlocEvents = observer.getEventsForBloc('MyBloc');
```

### Memory Monitoring Configuration

```dart
// Configure update intervals
AnimatedMemoryMonitor(
  updateInterval: Duration(milliseconds: 250), // Faster updates
)

// Configure memory limits
CircularMemoryMonitor(
  maxExpectedMemoryMB: 1000.0,
  databasePath: '/custom/path/database.db',
  showDatabaseMonitoring: true,
)
```

### Leak Detection Configuration

```dart
// Configure monitoring frequency
RealTimeLeakMonitor(
  checkInterval: Duration(seconds: 1), // More frequent checks
)
```

## 🎨 UI Features

### Visual Indicators

- **Color-coded Status**: Green (normal), Orange (warning), Red (critical)
- **Pulse Animations**: Visual feedback for performance spikes
- **Real-time Graphs**: Historical data visualization
- **Material Design**: Consistent with Flutter's design system

### BLoC Visualizer Features

- **Event Cards**: Blue for normal events, Red for errors
- **State Cards**: Green for state transitions
- **Filter Controls**: Dropdown selection, search field
- **Toggle Chips**: Show/hide different event types
- **Time Stamps**: Millisecond precision timing

## 🔬 TRIZ Principles

This package is built following TRIZ (Theory of Inventive Problem Solving) principles:

- **SEGMENTATION**: Separate concerns (observation vs visualization)
- **LOCAL QUALITY**: Each component optimized for its specific purpose
- **PRIOR COUNTERACTION**: Proactive error handling and resource management
- **SELF-SERVICE**: Autonomous operation with minimal configuration
- **UNIVERSALITY**: Works with different BLoC types and widget patterns
- **NESTED DOLL**: Hierarchical component architecture

## 📊 Performance Considerations

- **Memory Management**: Configurable limits prevent memory bloat
- **Efficient Updates**: Uses timers and animations optimally
- **Conditional Rendering**: Only active when needed
- **Resource Cleanup**: Proper disposal of controllers and listeners
- **Non-blocking Operations**: Doesn't interfere with app performance

## 🛡️ Error Handling

The package includes robust error handling:
- Graceful fallbacks for missing databases
- Exception catching in monitoring loops
- Resource cleanup on widget disposal
- Safe state updates with mounted checks

## 📝 Requirements

- **Dart**: `>=3.6.0 <4.0.0`
- **Flutter**: `>=3.24.0`

### Dependencies
- `flutter_bloc: ^9.1.1` - BLoC state management monitoring
- `leak_tracker: ^11.0.2` - Professional memory leak detection
- `overlay_support: ^2.1.0` - Overlay functionality
- `intl: ^0.20.2` - Internationalization support
- `path: ^1.9.0` - File path utilities

## 🤝 Contributing

Contributions are welcome! Please ensure your code follows TRIZ principles and includes appropriate documentation.

## 📄 License

This package is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Related Packages

- [leak_tracker](https://pub.dev/packages/leak_tracker) - Professional memory leak detection
- [flutter_bloc](https://pub.dev/packages/flutter_bloc) - BLoC state management
- [overlay_support](https://pub.dev/packages/overlay_support) - Overlay support

---

Built with ❤️ following TRIZ methodology for optimal performance monitoring.
