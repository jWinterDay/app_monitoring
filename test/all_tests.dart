// Master test file that imports and runs all tests
// Run with: flutter test test/all_tests.dart

import 'unit/bloc_debug_observer_test.dart' as bloc_observer_tests;
import 'unit/cpu_graph_painter_test.dart' as cpu_painter_tests;
import 'widget/circular_memory_monitor_test.dart' as memory_monitor_tests;
import 'widget/database_size_monitor_test.dart' as database_monitor_tests;
import 'widget/memory_leak_simulator_test.dart' as leak_simulator_tests;
import 'integration/app_monitoring_integration_test.dart' as integration_tests;

void main() {
  // Unit tests
  bloc_observer_tests.main();
  cpu_painter_tests.main();

  // Widget tests
  memory_monitor_tests.main();
  database_monitor_tests.main();
  leak_simulator_tests.main();

  // Integration tests
  integration_tests.main();
}
