# Bloc Monitoring System

A beautiful, real-time bloc state and event monitoring system with filtering capabilities, designed following TRIZ methodology principles.

## 🏗️ Architecture

### Files Structure
```
packages/app_monitoring/lib/src/bloc/
├── bloc_debug_observer.dart    # Core observer that captures bloc events/states
├── bloc_visualizer.dart        # Beautiful UI component for visualization
├── index.dart                  # Exports
└── README.md                   # This file
```

## 🚀 Features

### BlocDebugObserver
- **Real-time monitoring** of all bloc events and state changes
- **Memory-efficient storage** with configurable limits (default: 100 events per bloc)
- **Active bloc registry** for filtering and management
- **Error tracking** with special error event handling
- **Listener system** for real-time UI updates

### BlocVisualizer
- **Beautiful Material Design** UI with color-coded events and states
- **Filtering capabilities** - select specific blocs or view all
- **Search functionality** - filter by event/state names
- **Real-time updates** with auto-refresh
- **Toggle controls** - show/hide events and states independently
- **Time-stamped entries** with millisecond precision

### DebugOverview Integration
- **Seamless integration** into existing monitoring dashboard
- **Conditional display** - only shown when debug tools are enabled
- **Fixed height container** for optimal UX

## 🎨 UI Features

### Event Visualization
- **Blue cards** for regular events
- **Red cards** for error events
- **Event type display** with timestamp
- **Full event data** in monospace font

### State Change Visualization  
- **Green cards** for state transitions
- **Side-by-side comparison** of current → next state
- **Visual arrow** indicating transition direction
- **Type information** for both states

### Filtering & Controls
- **Dropdown selector** for specific bloc selection
- **Search field** for filtering events/states by name
- **Toggle chips** for showing/hiding event types
- **Clear buttons** for data management

## 🔧 Usage

### 1. Automatic Setup
The observer is automatically initialized in `main_common.dart` when debug tools are enabled:

```dart
// Automatically configured based on environment
if (appEnvUtils.appEnv.showDebugTools) {
  debugObserver = BlocDebugObserver();
  Bloc.observer = debugObserver;
}
```

### 2. Access in Debug Tools
Navigate to Debug Tools → Monitoring Overview to see the bloc monitor.

### 3. Filtering Blocs
- Use the dropdown to select a specific bloc
- Use the search field to filter events by name
- Toggle event/state visibility with the filter chips

### 4. Managing Data
- Click "Clear All" to reset all monitoring data  
- Click the individual clear button to clear data for selected bloc

## 🧠 TRIZ Principles Applied

### SEGMENTATION
- Separated concerns: observation vs visualization
- Modular file structure for maintainability

### LOCAL QUALITY
- BlocDebugObserver optimizes for memory efficiency
- BlocVisualizer optimizes for beautiful, responsive UI

### PRIOR COUNTERACTION
- Memory leak prevention with event limits
- Robust error handling and cleanup mechanisms

### SELF-SERVICE
- Auto-refresh for real-time updates
- Autonomous operation with minimal configuration

### UNIVERSALITY
- Works with both Bloc and Cubit instances
- Flexible visualization for any bloc type

### NESTED DOLL
- Hierarchical decomposition: Observer → Visualizer → DebugOverview

## 📊 Performance Considerations

- **Memory Management**: Limited to 100 events per bloc by default
- **Efficient Data Structures**: Uses `Queue<T>` for O(1) operations
- **Conditional Rendering**: Only active when debug tools enabled
- **Auto-cleanup**: Removes listeners on dispose

## 🛠️ Configuration

### Adjusting Event Limits
```dart
BlocDebugObserver(maxEventsPerBloc: 200) // Custom limit
```

### Custom Filtering
The visualizer includes built-in filtering, but you can extend the observer for custom logic.

## 🔍 Troubleshooting

### No Blocs Appearing
- Ensure debug tools are enabled in your environment
- Check that you're navigating through the app to trigger bloc events

### Performance Issues
- Reduce `maxEventsPerBloc` limit
- Clear data regularly using the UI controls

### Missing Events
- Verify that `Bloc.observer` is set to your `BlocDebugObserver` instance
- Check that the provider is correctly injected in the widget tree

## 🚀 Future Enhancements

- Export/import monitoring data
- Performance metrics visualization
- Bloc dependency graph
- Advanced filtering options
- Integration with DevTools
