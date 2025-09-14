import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leak_tracker/leak_tracker.dart';

import 'leak_location.dart';

/// Real-time memory leak monitor widget
/// Applies TRIZ principles: SELF-SERVICE (autonomous monitoring),
/// LOCAL QUALITY (optimized real-time display), PRIOR COUNTERACTION (error handling),
/// UNIVERSALITY (reusable monitoring pattern)
class RealTimeLeakMonitor extends StatefulWidget {
  const RealTimeLeakMonitor({super.key});

  @override
  State<RealTimeLeakMonitor> createState() => _RealTimeLeakMonitorState();
}

class _RealTimeLeakMonitorState extends State<RealTimeLeakMonitor> {
  Timer? _monitoringTimer;
  LeakSummary? _currentLeakSummary;
  Leaks? _currentLeaksDetailed;
  String _statusMessage = 'Initializing...';
  Color _statusColor = Colors.grey;
  DateTime? _lastCheck;
  DateTime? _lastDetailedCheck;
  bool _isMonitoring = false;
  bool _isManualGcInProgress = false;
  Map<String, int> _leaksByType = <String, int>{};
  List<String> _leakRecommendations = <String>[];
  String _severityLevel = 'Unknown';
  Map<String, List<LeakLocation>> _leaksByFile = <String, List<LeakLocation>>{};

  // Pagination state - tracks current page for each file
  final Map<String, int> _currentPageByFile = <String, int>{};
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    // Initial check
    _checkLeaks();

    // Set up periodic monitoring (every 2 seconds for real-time updates)
    _monitoringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _checkLeaks();
      }
    });

    setState(() {
      _isMonitoring = true;
    });
  }

  /// Non-destructive leak checking - does NOT trigger garbage collection
  /// GC COORDINATION FIX: Only uses checkLeaks() to avoid automatic GC triggering
  Future<void> _checkLeaks() async {
    try {
      if (!LeakTracking.isStarted) {
        setState(() {
          _statusMessage = 'Leak Tracker Not Started';
          _statusColor = Colors.orange;
          _lastCheck = DateTime.now();
        });
        return;
      }

      // Use ONLY non-destructive summary check - no GC triggering
      final LeakSummary leakSummary = await LeakTracking.checkLeaks();
      final String severity = _calculateSeverity(leakSummary.total);

      setState(() {
        _currentLeakSummary = leakSummary;
        _severityLevel = severity;
        _lastCheck = DateTime.now();

        if (leakSummary.total == 0) {
          _statusMessage = 'No Leaks Detected ✅';
          _statusColor = Colors.green;
        } else {
          _statusMessage =
              '🚨 ${leakSummary.total} Leak${leakSummary.total > 1 ? 's' : ''} Detected ($severity) - Use "Analyze Details" for more info';
          _statusColor = _getSeverityColor(severity);
        }
      });
    } on Exception catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _statusColor = Colors.red;
        _lastCheck = DateTime.now();
      });
      developer.log('Real-time leak check error: $e');
    }
  }

  /// Manual detailed leak analysis - triggers GC and collects detailed leak data
  /// This is the method that forces garbage collection when user requests it
  Future<void> _performManualDetailedAnalysis() async {
    if (_isManualGcInProgress) return;

    setState(() {
      _isManualGcInProgress = true;
    });

    try {
      if (!LeakTracking.isStarted) {
        setState(() {
          _statusMessage = 'Leak Tracker Not Started';
          _statusColor = Colors.orange;
          _isManualGcInProgress = false;
        });
        return;
      }

      // Get updated summary first
      final LeakSummary leakSummary = await LeakTracking.checkLeaks();

      // NOW trigger GC and collect detailed leaks - this forces garbage collection
      final Leaks detailedLeaks = await LeakTracking.collectLeaks();

      developer.log(
        'RealTimeLeakMonitor: Manual GC triggered - Summary: ${leakSummary.total}, Detailed: ${detailedLeaks.total}',
      );

      // Analyze detailed leaks for comprehensive information
      final Map<String, int> leaksByType = _analyzeLeakTypesFromDetailed(detailedLeaks);
      final List<LeakLocation> leakLocations = _extractLeakLocationsFromDetailed(detailedLeaks);
      final Map<String, List<LeakLocation>> leaksByFile = _groupLeaksByFile(leakLocations);
      final List<String> recommendations = _generateRecommendationsFromDetailed(detailedLeaks, leaksByType);
      final String severity = _calculateSeverity(detailedLeaks.total);

      setState(() {
        // Reset pagination for new detailed data
        if (_shouldResetPagination(leaksByFile)) {
          developer.log('RealTimeLeakMonitor: Resetting pagination for detailed analysis');
          _resetPagination();
        }

        _currentLeakSummary = leakSummary;
        _currentLeaksDetailed = detailedLeaks;
        _leaksByType = leaksByType;
        _leaksByFile = leaksByFile;
        _leakRecommendations = recommendations;
        _severityLevel = severity;
        _lastCheck = DateTime.now();
        _lastDetailedCheck = DateTime.now();
        _isManualGcInProgress = false;

        // Adjust pagination bounds
        _adjustPaginationBounds();

        if (detailedLeaks.total == 0) {
          _statusMessage = 'No Leaks After GC ✅ (Detailed Analysis Complete)';
          _statusColor = Colors.green;
        } else {
          _statusMessage =
              '🚨 ${detailedLeaks.total} True Leak${detailedLeaks.total > 1 ? 's' : ''} Found ($severity) - Post-GC Analysis';
          _statusColor = _getSeverityColor(severity);
        }
      });
    } on Exception catch (e) {
      setState(() {
        _statusMessage = 'Detailed analysis error: $e';
        _statusColor = Colors.red;
        _lastCheck = DateTime.now();
        _isManualGcInProgress = false;
      });
      developer.log('Manual detailed leak analysis error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
        color: _statusColor.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Status header with indicator and manual GC button
          Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: (textTheme.titleSmall ?? const TextStyle()).copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Manual GC Analysis Button
              if (LeakTracking.isStarted) ...<Widget>[
                ElevatedButton.icon(
                  onPressed: _isManualGcInProgress ? null : _performManualDetailedAnalysis,
                  icon: _isManualGcInProgress
                      ? SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                          ),
                        )
                      : const Icon(Icons.play_arrow, size: 16),
                  label: Text(
                    _isManualGcInProgress ? 'Analyzing...' : 'Analyze Details',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 11),
                    backgroundColor: _isManualGcInProgress ? Colors.grey.shade300 : Colors.blue.shade600,
                    foregroundColor: _isManualGcInProgress ? Colors.grey.shade600 : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Monitoring indicator
              if (_isMonitoring) ...<Widget>[
                Icon(
                  Icons.radio_button_checked,
                  size: 12,
                  color: Colors.blue.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Live',
                  style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                    color: Colors.blue.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),

          // Information about GC behavior
          if (LeakTracking.isStarted) ...<Widget>[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Live monitoring shows potential leaks. Click "Analyze Details" to trigger GC and find true leaks.',
                      style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                        color: Colors.blue.shade700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Detailed information
          if (LeakTracking.isStarted && _currentLeakSummary != null) ...<Widget>[
            // Human-readable leak analysis
            if (_currentLeakSummary!.total > 0) ...<Widget>[
              // Severity and overview
              Row(
                children: <Widget>[
                  Icon(
                    _getSeverityIcon(_severityLevel),
                    size: 16,
                    color: _getSeverityColor(_severityLevel),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Severity: $_severityLevel',
                    style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getSeverityColor(_severityLevel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Leak types breakdown
              if (_leaksByType.isNotEmpty) ...<Widget>[
                Text(
                  'Leak Types:',
                  style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ...(_leaksByType.entries.map(
                  (MapEntry<String, int> entry) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _getLeakTypeIcon(entry.key),
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${entry.key}: ${entry.value}',
                          style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 8),
              ],

              // Leak locations by file
              if (_leaksByFile.isNotEmpty) ...<Widget>[
                Text(
                  '📍 Leak Locations:',
                  style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...(_leaksByFile.entries.map(
                  (MapEntry<String, List<LeakLocation>> fileEntry) {
                    return _buildFileLeakSection(fileEntry.key, fileEntry.value, textTheme);
                  },
                )),
                const SizedBox(height: 8),
              ],

              // Recommendations
              if (_leakRecommendations.isNotEmpty) ...<Widget>[
                Text(
                  '💡 Recommendations:',
                  style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                ...(_leakRecommendations.map(
                  (String recommendation) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '• ',
                          style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 8),
              ],

              // Raw technical details (always visible)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Technical Details',
                    style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Summary: ${_currentLeakSummary?.toMessage() ?? 'No leaks detected'}',
                          style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            height: 1.3,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (_currentLeaksDetailed != null && _currentLeaksDetailed!.total > 0) ...<Widget>[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Detailed True Leaks (${_currentLeaksDetailed!.total} items):',
                            style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // True leaks ListView
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: _currentLeaksDetailed!.all.length > 3 ? 300 : double.infinity,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: _currentLeaksDetailed!.all.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'No detailed leak data available',
                                      style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.all(8),
                                    physics: _currentLeaksDetailed!.all.length > 3
                                        ? const AlwaysScrollableScrollPhysics()
                                        : const NeverScrollableScrollPhysics(),
                                    itemCount: _currentLeaksDetailed!.all.length,
                                    separatorBuilder: (BuildContext context, int index) => Container(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                    itemBuilder: (BuildContext context, int index) {
                                      final LeakReport leak = _currentLeaksDetailed!.all[index];
                                      return _buildDetailedLeakItem(leak, index + 1, textTheme);
                                    },
                                  ),
                          ),
                          const SizedBox(height: 8),
                          // Raw YAML output (collapsible)
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                InkWell(
                                  onTap: () {
                                    // Toggle YAML visibility
                                    setState(() {
                                      // We'll add a state variable for this
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.code,
                                          size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Raw YAML Output',
                                          style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                                            color: Colors.grey.shade600,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      _currentLeaksDetailed!.toYaml(phasesAreTests: false),
                                      style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                                        fontFamily: 'monospace',
                                        fontSize: 8,
                                        height: 1.2,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
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
              ),
            ] else ...<Widget>[
              // No leaks - show positive status
              Row(
                children: <Widget>[
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Memory Management: Excellent',
                    style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'All Flutter widgets and controllers are properly disposed. No memory leaks detected.',
                style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                  color: Colors.green.shade600,
                  fontSize: 12,
                ),
              ),
              // const SizedBox(height: 8),
              // Container(
              //   padding: const EdgeInsets.all(8),
              //   decoration: BoxDecoration(
              //     color: Colors.blue.withValues(alpha: 0.1),
              //     borderRadius: BorderRadius.circular(4),
              //     border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              //   ),
              //   child: Text(
              //     '💡 Tip: Use the Memory Leak Simulator below to test leak detection. Create widgets, then hide them to trigger leaks!',
              //     style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
              //       color: Colors.blue.shade700,
              //       fontSize: 11,
              //       fontStyle: FontStyle.italic,
              //     ),
              //   ),
              // ),
            ],
          ] else ...<Widget>[
            Text(
              _getStatusDescription(),
              style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Footer with last check time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Monitoring: ${_isMonitoring ? 'Active (No GC)' : 'Inactive'}',
                    style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                      color: _isMonitoring ? Colors.green : Colors.grey,
                    ),
                  ),
                  if (_lastDetailedCheck != null)
                    Text(
                      'Last GC Analysis: ${_formatTime(_lastDetailedCheck!)}',
                      style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                        color: Colors.blue.shade600,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_lastCheck != null)
                    Text(
                      'Summary: ${_formatTime(_lastCheck!)}',
                      style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (_currentLeaksDetailed != null)
                    Text(
                      'Details: ${_currentLeaksDetailed!.total} true leaks',
                      style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                        color: _currentLeaksDetailed!.total > 0 ? Colors.red.shade600 : Colors.green.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStatusDescription() {
    if (!LeakTracking.isStarted) {
      return 'Leak tracker not initialized';
    }
    return 'Non-destructive monitoring active - no automatic GC triggering. Use "Analyze Details" button for deep analysis with GC.';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  /// Resets pagination state when leaks change
  /// Applies TRIZ SELF-SERVICE: autonomous pagination management
  void _resetPagination() {
    _currentPageByFile.clear();
  }

  /// Determines if pagination should be reset based on leak structure changes
  /// Applies TRIZ PRIOR COUNTERACTION: prevents unnecessary pagination resets
  /// CONSERVATIVE APPROACH: Only reset when absolutely necessary to preserve user's current page
  bool _shouldResetPagination(Map<String, List<LeakLocation>> newLeaksByFile) {
    // If no previous data, don't reset (initial load)
    if (_leaksByFile.isEmpty) {
      return false;
    }

    // Only check if file structure has changed (files added/removed)
    final Set<String> previousFiles = _leaksByFile.keys.toSet();
    final Set<String> newFiles = newLeaksByFile.keys.toSet();

    // Reset only if files were added or removed (structural change)
    if (!previousFiles.containsAll(newFiles) || !newFiles.containsAll(previousFiles)) {
      return true;
    }

    // Check for major leak count changes that would affect pagination structure
    for (final String fileName in newFiles) {
      final int previousCount = _leaksByFile[fileName]?.length ?? 0;
      final int newCount = newLeaksByFile[fileName]?.length ?? 0;

      // Only reset if leak count changed dramatically (>50% AND more than 10 items)
      // This catches major structural changes while preserving pagination for minor fluctuations
      if (previousCount > 0 && newCount > 0) {
        final double changeRatio = (previousCount - newCount).abs() / previousCount;
        final int changeCount = (previousCount - newCount).abs();

        // Reset only for very significant changes (both percentage and absolute)
        if (changeRatio > 0.5 && changeCount > 10) {
          return true;
        }
      }

      // Reset if a file went from having leaks to no leaks or vice versa
      if ((previousCount == 0 && newCount > 5) || (previousCount > 5 && newCount == 0)) {
        return true;
      }
    }

    return false;
  }

  /// Adjusts pagination bounds to ensure current pages are valid
  /// Applies TRIZ LOCAL QUALITY: maintain valid state per file
  /// CONSERVATIVE APPROACH: Preserve user's current page as much as possible
  void _adjustPaginationBounds() {
    final List<String> filesToRemove = <String>[];

    for (final MapEntry<String, int> entry in _currentPageByFile.entries) {
      final String fileName = entry.key;
      final int currentPage = entry.value;

      // Check if this file still exists
      if (!_leaksByFile.containsKey(fileName)) {
        filesToRemove.add(fileName);
        continue;
      }

      final List<LeakLocation> leaks = _leaksByFile[fileName] ?? <LeakLocation>[];
      final int totalPages = _getTotalPages(leaks);

      // Only adjust if current page is actually out of bounds
      if (totalPages > 0 && currentPage >= totalPages) {
        // Try to stay as close to current position as possible
        // If we were on page 5 and now only have 3 pages, go to page 2 (last valid page)
        final int newPage = totalPages - 1;
        developer.log(
          'RealTimeLeakMonitor: Adjusting pagination for $fileName from page $currentPage to page $newPage (totalPages: $totalPages)',
        );
        _currentPageByFile[fileName] = newPage;
      } else if (totalPages == 0) {
        // If no pages available, reset to 0
        developer.log('RealTimeLeakMonitor: No leaks in $fileName, resetting to page 0');
        _currentPageByFile[fileName] = 0;
      }
      // If current page is still valid (currentPage < totalPages), don't change it
    }

    // Remove pagination state for files that no longer exist
    for (final String fileName in filesToRemove) {
      _currentPageByFile.remove(fileName);
    }
  }

  /// Gets current page for a file (defaults to 0)
  int _getCurrentPage(String fileName) {
    return _currentPageByFile[fileName] ?? 0;
  }

  /// Sets current page for a file
  void _setCurrentPage(String fileName, int page) {
    setState(() {
      _currentPageByFile[fileName] = page;
    });
  }

  /// Gets paginated leaks for a file
  /// Applies TRIZ SEGMENTATION: breaking large lists into manageable chunks
  List<LeakLocation> _getPaginatedLeaks(String fileName, List<LeakLocation> allLeaks) {
    final int currentPage = _getCurrentPage(fileName);
    final int startIndex = currentPage * _itemsPerPage;
    final int endIndex = (startIndex + _itemsPerPage).clamp(0, allLeaks.length);

    if (startIndex >= allLeaks.length) {
      return <LeakLocation>[];
    }

    return allLeaks.sublist(startIndex, endIndex);
  }

  /// Gets total number of pages for a file
  int _getTotalPages(List<LeakLocation> allLeaks) {
    return (allLeaks.length / _itemsPerPage).ceil();
  }

  /// Checks if there's a previous page
  bool _hasPreviousPage(String fileName) {
    return _getCurrentPage(fileName) > 0;
  }

  /// Checks if there's a next page
  bool _hasNextPage(String fileName, List<LeakLocation> allLeaks) {
    final int currentPage = _getCurrentPage(fileName);
    final int totalPages = _getTotalPages(allLeaks);
    return currentPage < totalPages - 1;
  }

  /// Analyzes detailed leak data to categorize leak types for human-readable display
  /// Applies TRIZ LOCAL QUALITY principle: optimized categorization using precise leak data
  Map<String, int> _analyzeLeakTypesFromDetailed(Leaks detailedLeaks) {
    final Map<String, int> leaksByType = <String, int>{};

    // Process all leak reports from all leak types
    for (final LeakReport leak in detailedLeaks.all) {
      final String objectType = leak.type;
      final String categoryName;

      // Categorize based on the actual object type
      if (objectType.contains('TextEditingController')) {
        categoryName = 'Text Controllers';
      } else if (objectType.contains('ScrollController')) {
        categoryName = 'Scroll Controllers';
      } else if (objectType.contains('AnimationController')) {
        categoryName = 'Animation Controllers';
      } else if (objectType.contains('Widget') || objectType.contains('Element')) {
        categoryName = 'Widgets/Elements';
      } else if (objectType.contains('Stream')) {
        categoryName = 'Stream Controllers';
      } else if (objectType.contains('Timer')) {
        categoryName = 'Timers';
      } else if (objectType.contains('Controller')) {
        categoryName = 'Other Controllers';
      } else {
        categoryName = objectType; // Use the actual type name for specific identification
      }

      leaksByType[categoryName] = (leaksByType[categoryName] ?? 0) + 1;
    }

    return leaksByType;
  }

  /// Generates actionable recommendations based on detailed leak data
  /// Applies TRIZ PRIOR COUNTERACTION: proactive guidance for leak resolution with specific context
  List<String> _generateRecommendationsFromDetailed(Leaks detailedLeaks, Map<String, int> leaksByType) {
    final List<String> recommendations = <String>[];

    if (detailedLeaks.total == 0) return recommendations;

    // General recommendations based on leak severity
    if (detailedLeaks.total >= 10) {
      recommendations
          .add('CRITICAL: High leak count detected. Review app architecture and lifecycle management immediately.');
    } else if (detailedLeaks.total >= 5) {
      recommendations.add('WARNING: Multiple leaks detected. Consider reviewing recent code changes.');
    }

    // Specific recommendations based on leak types and actual leak context
    for (final MapEntry<String, int> entry in leaksByType.entries) {
      switch (entry.key) {
        case 'Text Controllers':
          recommendations.add('Add textController.dispose() in your StatefulWidget dispose() methods.');
          recommendations.add('Ensure TextField widgets properly dispose their controllers.');
        case 'Scroll Controllers':
          recommendations.add('Add scrollController.dispose() in your StatefulWidget dispose() methods.');
          recommendations.add('Check ListView, GridView, and ScrollView controller cleanup.');
        case 'Animation Controllers':
          recommendations.add('Add animationController.dispose() in your StatefulWidget dispose() methods.');
          recommendations.add('Verify all AnimationController instances are properly disposed.');
        case 'Widgets/Elements':
          recommendations.add('Review StatefulWidget lifecycle - ensure proper dispose() implementation.');
          recommendations.add('Check for retained references to widgets or GlobalKeys.');
        case 'Stream Controllers':
          recommendations.add('Cancel StreamSubscription instances in dispose() methods.');
          recommendations.add('Close StreamController instances properly.');
        case 'Timers':
          recommendations.add('Cancel Timer instances in dispose() methods.');
          recommendations.add('Use periodic timers with proper cleanup.');
        default:
          // Specific type-based recommendation
          recommendations.add('Review disposal of ${entry.key} instances (${entry.value} leaks detected).');
      }
    }

    // Context-based recommendations from actual leak data
    if (detailedLeaks.all.isNotEmpty) {
      final Set<String> phases = detailedLeaks.all
          .where((LeakReport leak) => leak.phase != null && leak.phase!.isNotEmpty)
          .map((LeakReport leak) => leak.phase!)
          .toSet();

      if (phases.isNotEmpty) {
        recommendations.add('Leaks detected in phases: ${phases.join(', ')}. Review test setup and teardown.');
      }
    }

    // General best practices
    recommendations.add('Use Flutter Inspector to identify specific leaked objects.');
    recommendations.add('Run flutter analyze to check for potential lifecycle issues.');

    return recommendations;
  }

  /// Calculates leak severity level for user-friendly display
  /// Applies TRIZ SEGMENTATION: categorized severity levels
  String _calculateSeverity(int leakCount) {
    if (leakCount == 0) return 'None';
    if (leakCount <= 2) return 'Low';
    if (leakCount <= 5) return 'Medium';
    if (leakCount <= 10) return 'High';
    return 'Critical';
  }

  /// Gets color based on severity level
  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'None':
        return Colors.green;
      case 'Low':
        return Colors.orange;
      case 'Medium':
        return Colors.deepOrange;
      case 'High':
        return Colors.red;
      case 'Critical':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  /// Gets icon based on severity level
  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'None':
        return Icons.check_circle;
      case 'Low':
        return Icons.warning_amber;
      case 'Medium':
        return Icons.warning;
      case 'High':
        return Icons.error;
      case 'Critical':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  /// Gets icon for different leak types
  IconData _getLeakTypeIcon(String leakType) {
    switch (leakType) {
      case 'Text Controllers':
        return Icons.text_fields;
      case 'Scroll Controllers':
        return Icons.vertical_align_center;
      case 'Animation Controllers':
        return Icons.animation;
      case 'Widgets/Elements':
        return Icons.widgets;
      case 'Flutter Objects':
        return Icons.flutter_dash;
      default:
        return Icons.memory;
    }
  }

  /// Extracts precise leak locations from detailed leak data
  /// Applies TRIZ SEGMENTATION: isolate location data for targeted fixes with full context
  List<LeakLocation> _extractLeakLocationsFromDetailed(Leaks detailedLeaks) {
    final List<LeakLocation> locations = <LeakLocation>[];

    // Process all leak reports to extract precise location information
    for (final LeakReport leak in detailedLeaks.all) {
      String filePath = 'Unknown location';
      int lineNumber = 0;
      final List<String> stackTrace = <String>[];
      String creationLocation = '';

      // Extract stack trace from context if available
      final Map<String, dynamic>? context = leak.context;
      if (context != null) {
        // Look for start callstack (creation location)
        final dynamic startCallstack = context['start'];
        if (startCallstack is String && startCallstack.isNotEmpty) {
          creationLocation = 'Created at: $startCallstack';

          // Parse the first meaningful stack frame for file location
          final List<String> stackLines = startCallstack.split('\n');
          for (final String line in stackLines) {
            if (line.contains('.dart:')) {
              final RegExp fileRegex = RegExp(r'(.+\.dart):(\d+):?\d*');
              final Match? fileMatch = fileRegex.firstMatch(line);
              if (fileMatch != null && filePath == 'Unknown location') {
                filePath = fileMatch.group(1) ?? 'Unknown file';
                lineNumber = int.tryParse(fileMatch.group(2) ?? '0') ?? 0;
              }
            }
            // Add all meaningful stack trace lines
            if (line.trim().isNotEmpty && !line.contains('StackTrace') && !line.contains('#0')) {
              stackTrace.add(line.trim());
            }
          }
        }

        // Look for disposal callstack if available
        final dynamic disposalCallstack = context['disposal'];
        if (disposalCallstack is String && disposalCallstack.isNotEmpty) {
          stackTrace.addAll(<String>['', '--- Disposal Context ---']);
          final List<String> disposalLines = disposalCallstack.split('\n');
          for (final String line in disposalLines) {
            if (line.trim().isNotEmpty) {
              stackTrace.add(line.trim());
            }
          }
        }

        // Look for retaining path information
        final dynamic retainingPath = context['path'];
        if (retainingPath is String && retainingPath.isNotEmpty) {
          stackTrace.addAll(<String>['', '--- Retaining Path ---', retainingPath]);
        }
      }

      // Create precise leak location with all available information
      locations.add(
        LeakLocation(
          objectType: leak.type, // Exact type from leak tracker
          objectId: leak.code.toString(), // Use identity hash code as ID
          filePath: filePath,
          lineNumber: lineNumber,
          stackTrace: stackTrace,
          creationLocation: creationLocation.isEmpty
              ? 'Phase: ${leak.phase ?? "Unknown"}, TrackedClass: ${leak.trackedClass}'
              : creationLocation,
        ),
      );
    }

    return locations;
  }

  /// Groups leak locations by file for organized display
  /// Applies TRIZ NESTED DOLL: hierarchical organization (file → leaks)
  Map<String, List<LeakLocation>> _groupLeaksByFile(List<LeakLocation> locations) {
    final Map<String, List<LeakLocation>> fileGroups = <String, List<LeakLocation>>{};

    for (final LeakLocation location in locations) {
      final String fileName = location.filePath.split('/').last;
      final String displayPath = fileName.isEmpty ? 'Unknown File' : fileName;

      fileGroups.putIfAbsent(displayPath, () => <LeakLocation>[]);
      fileGroups[displayPath]!.add(location);
    }

    return fileGroups;
  }

  /// Builds UI section for leaks in a specific file
  /// Applies TRIZ LOCAL QUALITY: optimized display per file group
  Widget _buildFileLeakSection(String fileName, List<LeakLocation> leaks, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.red.shade300, width: 3)),
        color: Colors.red.shade50,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // File header with copy button
          Row(
            children: <Widget>[
              Icon(Icons.description, size: 16, color: Colors.red.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName,
                  style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
              if (leaks.isNotEmpty && leaks.first.filePath.isNotEmpty)
                IconButton(
                  onPressed: () => _copyFilePathToClipboard(context, leaks.first.filePath),
                  icon: Icon(Icons.copy, size: 14, color: Colors.red.shade600),
                  tooltip: 'Copy file path',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Leak entries for this file (paginated)
          ...(_getPaginatedLeaks(fileName, leaks).map((LeakLocation leak) => _buildLeakLocationItem(leak, textTheme))),

          // Pagination controls
          if (leaks.length > _itemsPerPage) _buildPaginationControls(fileName, leaks, textTheme),
        ],
      ),
    );
  }

  /// Builds individual leak location item
  /// Applies TRIZ UNIVERSALITY: reusable leak item pattern
  Widget _buildLeakLocationItem(LeakLocation leak, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Object type and location
          Row(
            children: <Widget>[
              Icon(
                _getLeakTypeIcon(leak.objectType),
                size: 14,
                color: Colors.red.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  leak.objectType,
                  style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
              if (leak.lineNumber > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Line ${leak.lineNumber}',
                    style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          if (leak.creationLocation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              leak.creationLocation,
              style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                color: Colors.red.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 11,
              ),
            ),
          ],

          // Expandable stack trace
          if (leak.stackTrace.isNotEmpty && !leak.stackTrace.first.contains('parsing failed'))
            ExpansionTile(
              title: Text(
                'Stack Trace (${leak.stackTrace.length} frames)',
                style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              dense: true,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: leak.stackTrace
                        .map(
                          (String frame) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              frame,
                              style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Builds pagination controls for a file's leak list
  /// Applies TRIZ LOCAL QUALITY: optimized navigation controls per file
  Widget _buildPaginationControls(String fileName, List<LeakLocation> allLeaks, TextTheme textTheme) {
    final int currentPage = _getCurrentPage(fileName);
    final int totalPages = _getTotalPages(allLeaks);
    final bool hasPrev = _hasPreviousPage(fileName);
    final bool hasNext = _hasNextPage(fileName, allLeaks);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Previous button
          IconButton(
            onPressed: hasPrev ? () => _setCurrentPage(fileName, currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: 'Previous page',
            style: IconButton.styleFrom(
              foregroundColor: hasPrev ? Colors.blue.shade700 : Colors.grey.shade400,
            ),
          ),

          // Page info
          Expanded(
            child: Center(
              child: Text(
                'Page ${currentPage + 1} of $totalPages (${allLeaks.length} leaks)',
                style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Next button
          IconButton(
            onPressed: hasNext ? () => _setCurrentPage(fileName, currentPage + 1) : null,
            icon: const Icon(Icons.chevron_right),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: 'Next page',
            style: IconButton.styleFrom(
              foregroundColor: hasNext ? Colors.blue.shade700 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds detailed leak item for ListView display
  /// Shows comprehensive leak information in structured format
  Widget _buildDetailedLeakItem(LeakReport leak, int itemNumber, TextTheme textTheme) {
    // Extract detailed location information from context
    final Map<String, String> locationInfo = _extractLocationInfo(leak);
    final List<String> stackFrames = _extractStackFrames(leak);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with item number and leak type
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$itemNumber',
                  style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  leak.type,
                  style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
              // Copy button for leak details
              IconButton(
                onPressed: () => _copyLeakDetailsToClipboard(context, leak, itemNumber),
                icon: Icon(Icons.copy, size: 16, color: Colors.grey.shade600),
                tooltip: 'Copy leak details',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // File location information (most important info first)
          if (locationInfo['fileName']?.isNotEmpty == true ||
              locationInfo['lineNumber']?.isNotEmpty == true) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.location_on, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Location Information',
                        style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (locationInfo['fileName']?.isNotEmpty == true) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.description, size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'File: ${locationInfo['fileName']}',
                            style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                              fontFamily: 'monospace',
                              color: Colors.blue.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copyFilePathToClipboard(
                              context, locationInfo['fullPath'] ?? locationInfo['fileName'] ?? '',),
                          icon: Icon(Icons.copy, size: 12, color: Colors.blue.shade600),
                          tooltip: 'Copy file path',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        ),
                      ],
                    ),
                  ],
                  if (locationInfo['lineNumber']?.isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Icon(Icons.format_line_spacing, size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Line: ${locationInfo['lineNumber']}',
                          style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                            color: Colors.blue.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (locationInfo['method']?.isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Icon(Icons.functions, size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Method: ${locationInfo['method']}',
                            style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                              fontFamily: 'monospace',
                              color: Colors.blue.shade800,
                              fontSize: 9,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Object details grid
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: <Widget>[
                // Object ID and Phase
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildDetailField(
                        'Object ID',
                        leak.code.toString(),
                        Icons.fingerprint,
                        textTheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailField(
                        'Phase',
                        (leak.phase?.isNotEmpty == true) ? leak.phase! : 'Unknown',
                        Icons.timeline,
                        textTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Tracked Class
                _buildDetailField(
                  'Tracked Class',
                  leak.trackedClass.isNotEmpty ? leak.trackedClass : 'N/A',
                  Icons.category,
                  textTheme,
                ),
              ],
            ),
          ),

          // Stack trace information
          if (stackFrames.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.call_split, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Stack Trace (${stackFrames.length} frames)',
                          style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: stackFrames.take(5).map((String frame) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              frame,
                              style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                                fontFamily: 'monospace',
                                fontSize: 8,
                                height: 1.2,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (stackFrames.length > 5)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '... and ${stackFrames.length - 5} more frames',
                        style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                          color: Colors.orange.shade600,
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Raw context information (simplified)
          if (leak.context != null && leak.context!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Additional Context',
                          style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 100),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: leak.context!.entries
                            .where((MapEntry<String, dynamic> entry) =>
                                !<String>['start', 'disposal', 'path'].contains(entry.key.toLowerCase()),)
                            .map((MapEntry<String, dynamic> entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '${entry.key}:',
                                    style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value?.toString() ?? 'null',
                                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                                      fontFamily: 'monospace',
                                      color: Colors.grey.shade800,
                                      fontSize: 8,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Helper method to build detail fields with consistent styling
  Widget _buildDetailField(String label, String value, IconData icon, TextTheme textTheme) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 14,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                  color: Colors.grey.shade800,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Extracts location information from leak context
  Map<String, String> _extractLocationInfo(LeakReport leak) {
    final Map<String, String> locationInfo = <String, String>{};

    if (leak.context == null) return locationInfo;

    // Look for start callstack (creation location)
    final dynamic startCallstack = leak.context!['start'];
    if (startCallstack is String && startCallstack.isNotEmpty) {
      // Parse the first meaningful stack frame for file location
      final List<String> stackLines = startCallstack.split('\n');
      for (final String line in stackLines) {
        if (line.contains('.dart:')) {
          // Extract file path and line number using regex
          final RegExp fileRegex = RegExp(r'(.+[\\/]([^/\\]+\.dart)):(\d+):?\d*');
          final Match? fileMatch = fileRegex.firstMatch(line);
          if (fileMatch != null) {
            locationInfo['fullPath'] = fileMatch.group(1) ?? '';
            locationInfo['fileName'] = fileMatch.group(2) ?? '';
            locationInfo['lineNumber'] = fileMatch.group(3) ?? '';

            // Extract method/function name
            final RegExp methodRegex = RegExp(r'(\w+\.\w+|\w+)');
            final List<RegExpMatch> methodMatches = methodRegex.allMatches(line).toList();
            if (methodMatches.isNotEmpty) {
              // Get the method name from the line
              for (final RegExpMatch match in methodMatches) {
                final String? method = match.group(0);
                if (method != null && method.contains('.') && !method.contains('dart')) {
                  locationInfo['method'] = method;
                  break;
                }
              }
            }
            break; // Use first dart file found
          }
        }
      }
    }

    return locationInfo;
  }

  /// Extracts stack frames from leak context
  List<String> _extractStackFrames(LeakReport leak) {
    final List<String> stackFrames = <String>[];

    if (leak.context == null) return stackFrames;

    // Look for start callstack
    final dynamic startCallstack = leak.context!['start'];
    if (startCallstack is String && startCallstack.isNotEmpty) {
      final List<String> lines = startCallstack.split('\n');
      for (final String line in lines) {
        final String cleanLine = line.trim();
        if (cleanLine.isNotEmpty && !cleanLine.contains('StackTrace') && !cleanLine.startsWith('===')) {
          stackFrames.add(cleanLine);
        }
      }
    }

    // Look for disposal callstack if available
    final dynamic disposalCallstack = leak.context!['disposal'];
    if (disposalCallstack is String && disposalCallstack.isNotEmpty) {
      stackFrames.add('--- Disposal Context ---');
      final List<String> disposalLines = disposalCallstack.split('\n');
      for (final String line in disposalLines) {
        final String cleanLine = line.trim();
        if (cleanLine.isNotEmpty) {
          stackFrames.add(cleanLine);
        }
      }
    }

    return stackFrames;
  }

  /// Copy complete leak details to clipboard
  Future<void> _copyLeakDetailsToClipboard(BuildContext context, LeakReport leak, int itemNumber) async {
    try {
      final StringBuffer details = StringBuffer();
      details.writeln('=== MEMORY LEAK DETAILS #$itemNumber ===');
      details.writeln('Type: ${leak.type}');
      details.writeln('Object ID: ${leak.code}');
      details.writeln('Phase: ${(leak.phase?.isNotEmpty == true) ? leak.phase! : 'Unknown'}');
      details.writeln('Tracked Class: ${leak.trackedClass.isNotEmpty ? leak.trackedClass : 'N/A'}');
      details.writeln();

      // Add location information
      final Map<String, String> locationInfo = _extractLocationInfo(leak);
      if (locationInfo.isNotEmpty) {
        details.writeln('=== LOCATION INFORMATION ===');
        if (locationInfo['fileName']?.isNotEmpty == true) {
          details.writeln('File: ${locationInfo['fileName']}');
        }
        if (locationInfo['fullPath']?.isNotEmpty == true) {
          details.writeln('Full Path: ${locationInfo['fullPath']}');
        }
        if (locationInfo['lineNumber']?.isNotEmpty == true) {
          details.writeln('Line: ${locationInfo['lineNumber']}');
        }
        if (locationInfo['method']?.isNotEmpty == true) {
          details.writeln('Method: ${locationInfo['method']}');
        }
        details.writeln();
      }

      // Add stack trace
      final List<String> stackFrames = _extractStackFrames(leak);
      if (stackFrames.isNotEmpty) {
        details.writeln('=== STACK TRACE ===');
        for (final String frame in stackFrames) {
          details.writeln(frame);
        }
        details.writeln();
      }

      // Add context
      if (leak.context != null && leak.context!.isNotEmpty) {
        details.writeln('=== CONTEXT ===');
        for (final MapEntry<String, dynamic> entry in leak.context!.entries) {
          details.writeln('${entry.key}: ${entry.value?.toString() ?? 'null'}');
        }
      }

      await Clipboard.setData(ClipboardData(text: details.toString()));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Leak #$itemNumber details copied to clipboard'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on Exception catch (e) {
      developer.log('Failed to copy leak details to clipboard: $e');
    }
  }

  /// Copy file path to clipboard with user feedback
  Future<void> _copyFilePathToClipboard(BuildContext context, String filePath) async {
    try {
      await Clipboard.setData(ClipboardData(text: filePath));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('File path copied to clipboard'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on Exception catch (e) {
      developer.log('Failed to copy file path to clipboard: $e');
    }
  }
}
