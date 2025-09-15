import 'dart:async';

import 'package:app_monitoring/src/bloc/bloc_debug_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Represents a difference between two state field values
class StateDiff {
  const StateDiff({
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    required this.changeType,
  });

  final String fieldName;
  final String oldValue;
  final String newValue;
  final StateDiffType changeType;
}

enum StateDiffType {
  modified, // Field value changed
  added, // Field was added
  removed, // Field was removed
}

/// A beautiful UI widget that visualizes bloc events and states in real-time
///
/// Applies TRIZ UNIVERSALITY: Can display different types of bloc data
/// and SELF-SERVICE: Operates autonomously with minimal configuration
class BlocVisualizer extends StatefulWidget {
  const BlocVisualizer({
    super.key,
    required this.observer,
  });

  final BlocDebugObserver observer;

  @override
  State<BlocVisualizer> createState() => _BlocVisualizerState();
}

class _BlocVisualizerState extends State<BlocVisualizer> {
  String? _selectedBloc;
  final bool _showEvents = true;
  final bool _showStates = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    widget.observer.addListener(_onObserverChanged);

    // Auto-refresh for real-time updates - applying TRIZ SELF-SERVICE
    // Reduced frequency to prevent mouse tracker conflicts and use post-frame callbacks
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    });
  }

  @override
  void dispose() {
    widget.observer.removeListener(_onObserverChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onObserverChanged() {
    if (mounted) {
      // Use post-frame callback to avoid gesture conflicts during frame updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> activeBlocs = widget.observer.activeBlocs;

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2, // Reduced elevation to minimize shadow calculations
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Optimize layout calculations
        children: <Widget>[
          // Header with controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.memory,
                      color: theme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bloc Monitor',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    _buildClearAllButton(theme),
                  ],
                ),
                const SizedBox(height: 16),

                // Bloc selector and toggles
                _buildControlsOnly(theme, activeBlocs),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: _selectedBloc == null ? _buildBlocSelectionView(theme, activeBlocs) : _buildBlocDetailsView(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOnly(ThemeData theme, List<String> activeBlocs) {
    return Column(
      children: <Widget>[
        // Bloc selector dropdown
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedBloc,
                decoration: InputDecoration(
                  labelText: 'Select Bloc',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    child: Text('All Blocs Overview'),
                  ),
                  ...activeBlocs.map(
                    (String bloc) => DropdownMenuItem<String>(
                      value: bloc,
                      child: Text(bloc),
                    ),
                  ),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _selectedBloc = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),

            // Clear selected bloc button
            if (_selectedBloc != null)
              IconButton(
                onPressed: () => widget.observer.clearBlocData(_selectedBloc!),
                icon: const Icon(Icons.clear),
                tooltip: 'Clear data for $_selectedBloc',
              ),
          ],
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildClearAllButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: () {
        widget.observer.clearAllData();
        setState(() {
          _selectedBloc = null;
        });
      },
      icon: const Icon(Icons.delete_sweep, size: 16),
      label: const Text('Clear All'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey.shade100,
        foregroundColor: Colors.blueGrey.shade700,
        elevation: 0,
      ),
    );
  }

  Widget _buildBlocSelectionView(ThemeData theme, List<String> activeBlocs) {
    if (activeBlocs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.hourglass_empty,
                size: 48, // Reduced from 64
                color: Colors.grey,
              ),
              SizedBox(height: 12), // Reduced from 16
              Text(
                'No active blocs yet',
                style: TextStyle(
                  fontSize: 16, // Reduced from 18
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6), // Reduced from 8
              Text(
                'Navigate through the app to see bloc activity',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeBlocs.length,
      itemBuilder: (BuildContext context, int index) {
        final String blocName = activeBlocs[index];
        final List<BlocEventRecord> events = widget.observer.getEventsForBloc(blocName);
        final List<BlocStateRecord> states = widget.observer.getStatesForBloc(blocName);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
              child: Icon(
                Icons.developer_board,
                color: theme.primaryColor,
                size: 20,
              ),
            ),
            title: Text(
              blocName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${events.length} events • ${states.length} states',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCreationTime(widget.observer.getBlocCreationDate(blocName)),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedBloc = blocName;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildBlocDetailsView(ThemeData theme) {
    final List<BlocEventRecord> events = widget.observer.getEventsForBloc(_selectedBloc!);
    final List<BlocStateRecord> states = widget.observer.getStatesForBloc(_selectedBloc!);

    // Get events and states based on toggles (no text filtering)
    final List<BlocEventRecord> filteredEvents = _showEvents ? events : <BlocEventRecord>[];
    final List<BlocStateRecord> filteredStates = _showStates ? states : <BlocStateRecord>[];

    // Combine and sort by timestamp
    final List<dynamic> allItems = <dynamic>[...filteredEvents, ...filteredStates]..sort((dynamic a, dynamic b) {
        final DateTime timestampA = a is BlocEventRecord ? a.timestamp : (a as BlocStateRecord).timestamp;
        final DateTime timestampB = b is BlocEventRecord ? b.timestamp : (b as BlocStateRecord).timestamp;
        return timestampB.compareTo(timestampA); // Most recent first
      });

    if (allItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.toggle_off,
                size: 48, // Reduced from 64 to save space
                color: Colors.grey,
              ),
              SizedBox(height: 12), // Reduced from 16
              Text(
                'No data to display',
                style: TextStyle(
                  fontSize: 16, // Reduced from 18
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6), // Reduced from 8
              Text(
                'Try enabling Events/States toggles or interact with the app',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      itemBuilder: (BuildContext context, int index) {
        final dynamic item = allItems[index];

        if (item is BlocEventRecord) {
          return _buildEventCard(theme, item);
        } else if (item is BlocStateRecord) {
          return _buildStateCard(theme, item);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEventCard(ThemeData theme, BlocEventRecord event) {
    final bool isError = event.isError;
    final Color cardColor = isError ? Colors.red.shade50 : Colors.blue.shade50;
    final MaterialColor iconColor = isError ? Colors.red : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  isError ? Icons.error : Icons.flash_on,
                  color: iconColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.eventType,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: iconColor.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                Text(
                  _formatTime(event.timestamp),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (event.event != null && !isError) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _extractEventDetails(event.event!),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ],
            if (isError && event.event is BlocErrorEvent) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                (event.event! as BlocErrorEvent).error.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStateCard(ThemeData theme, BlocStateRecord state) {
    final List<StateDiff> diffs = _calculateStateDiff(state.currentState, state.nextState);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.radio_button_checked,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'State Change',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                Text(
                  _formatTime(state.timestamp),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Show compact state type info if different
            if (state.currentStateType != state.nextStateType) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.swap_horiz, size: 12, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Type Changed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Action buttons for state values
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildCopyButton(
                    'Copy Old State',
                    state.currentState?.toString() ?? 'null',
                    Icons.copy_outlined,
                    Colors.red.shade100,
                    Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCopyButton(
                    'Copy New State',
                    state.nextState?.toString() ?? 'null',
                    Icons.copy,
                    Colors.green.shade100,
                    Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildShowFullStateButton(state),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Show field changes in compact format
            if (diffs.isNotEmpty)
              _buildCompactDiffDisplay(diffs)
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No field changes detected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
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

  /// Extract meaningful details from event objects, especially freezed models
  String _extractEventDetails(Object event) {
    // Try to extract meaningful information using runtime checks
    final String typeName = event.runtimeType.toString();

    try {
      // Check if it's a simple type that can be displayed directly
      if (event is String || event is num || event is bool) {
        return '$typeName: $event';
      }

      // For complex objects, try to extract field information using reflection-like approach
      final String stringRep = event.toString();
      if (stringRep != "Instance of '$typeName'" && !stringRep.startsWith("Instance of '")) {
        // If toString() is overridden and meaningful, use it (common in freezed models)
        if (stringRep.length < 200) {
          // Avoid very long strings
          return stringRep;
        } else {
          // Truncate long strings but keep structure visible
          return '${stringRep.substring(0, 197)}...';
        }
      }

      // Try to access common properties that events might have
      final Map<String, dynamic> eventMap = _tryExtractFields(event);
      if (eventMap.isNotEmpty) {
        final List<String> parts =
            eventMap.entries.map((MapEntry<String, dynamic> e) => '${e.key}: ${e.value}').toList();

        if (parts.isNotEmpty) {
          final String result = parts.join(', ');
          return result.length > 150 ? '${result.substring(0, 147)}...' : result;
        }
      }

      // Fallback: just show the type name
      return typeName;
    } on Exception catch (_) {
      // Safe fallback if any extraction fails
      return typeName;
    }
  }

  /// Calculate the difference between two states, showing only what changed
  List<StateDiff> _calculateStateDiff(dynamic currentState, dynamic nextState) {
    final List<StateDiff> diffs = <StateDiff>[];

    try {
      // If states are null or same reference, no diff
      if (currentState == null && nextState == null) return diffs;
      if (identical(currentState, nextState)) return diffs;

      // Handle null cases
      if (currentState == null) {
        diffs.add(
          StateDiff(
            fieldName: 'state',
            oldValue: 'null',
            newValue: _truncateValue(nextState.toString()),
            changeType: StateDiffType.added,
          ),
        );
        return diffs;
      }

      if (nextState == null) {
        diffs.add(
          StateDiff(
            fieldName: 'state',
            oldValue: _truncateValue(currentState.toString()),
            newValue: 'null',
            changeType: StateDiffType.removed,
          ),
        );
        return diffs;
      }

      // Extract fields from both states
      final Map<String, String> currentFields = _extractStateFields(currentState);
      final Map<String, String> nextFields = _extractStateFields(nextState);

      // Find all unique field names
      final Set<String> allFields = <String>{...currentFields.keys, ...nextFields.keys};

      for (final String field in allFields) {
        final String? currentValue = currentFields[field];
        final String? nextValue = nextFields[field];

        if (currentValue == null && nextValue != null) {
          // Field was added
          diffs.add(
            StateDiff(
              fieldName: field,
              oldValue: '',
              newValue: nextValue,
              changeType: StateDiffType.added,
            ),
          );
        } else if (currentValue != null && nextValue == null) {
          // Field was removed
          diffs.add(
            StateDiff(
              fieldName: field,
              oldValue: currentValue,
              newValue: '',
              changeType: StateDiffType.removed,
            ),
          );
        } else if (currentValue != nextValue) {
          // Field was modified
          diffs.add(
            StateDiff(
              fieldName: field,
              oldValue: currentValue ?? '',
              newValue: nextValue ?? '',
              changeType: StateDiffType.modified,
            ),
          );
        }
      }
    } on Exception catch (_) {
      // If diff calculation fails, fall back to simple comparison
      if (currentState.toString() != nextState.toString()) {
        diffs.add(
          StateDiff(
            fieldName: 'state',
            oldValue: _truncateValue(currentState.toString()),
            newValue: _truncateValue(nextState.toString()),
            changeType: StateDiffType.modified,
          ),
        );
      }
    }

    return diffs;
  }

  /// Extract fields from a state object using string parsing
  Map<String, String> _extractStateFields(dynamic state) {
    final Map<String, String> fields = <String, String>{};

    try {
      final String stateStr = state.toString();

      // Look for patterns like "field: value" in the string representation
      final RegExp pattern = RegExp(r'(\w+):\s*([^,)}\]]+)');
      final Iterable<RegExpMatch> matches = pattern.allMatches(stateStr);

      for (final RegExpMatch match in matches) {
        if (match.groupCount >= 2) {
          final String key = match.group(1)!;
          final String value = match.group(2)!.trim();
          // Truncate values to prevent overflow
          fields[key] = _truncateValue(value);
        }
      }
    } on Exception catch (_) {
      // If parsing fails, return empty map
    }

    return fields;
  }

  /// Build a copy button for copying full state values
  Widget _buildCopyButton(String label, String content, IconData icon, Color backgroundColor, Color textColor) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: content));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label copied to clipboard'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a compact display of state differences using Wrap
  Widget _buildCompactDiffDisplay(List<StateDiff> diffs) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.compare_arrows,
                size: 16,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Changes (${diffs.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: diffs.map((StateDiff diff) => _buildCompactDiffChip(diff)).toList(),
          ),
        ],
      ),
    );
  }

  /// Build a compact chip representation of a single diff
  Widget _buildCompactDiffChip(StateDiff diff) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    String prefix;

    switch (diff.changeType) {
      case StateDiffType.added:
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        textColor = Colors.green.shade700;
        prefix = '+';
        break;
      case StateDiffType.removed:
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        textColor = Colors.red.shade700;
        prefix = '-';
        break;
      case StateDiffType.modified:
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        textColor = Colors.orange.shade700;
        prefix = '~';
        break;
    }

    return InkWell(
      onTap: () {
        // Show detailed diff in a dialog
        _showDiffDialog(diff);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              prefix,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                diff.fieldName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a button to show full state in a beautiful dialog
  Widget _buildShowFullStateButton(BlocStateRecord state) {
    return InkWell(
      onTap: () {
        _showFullStateDialog(state);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.shade700.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.visibility, size: 14, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Show Full State',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show full state information in a beautiful dialog
  void _showFullStateDialog(BlocStateRecord state) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: <Widget>[
              Icon(
                Icons.account_tree,
                size: 24,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Full State View',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // State type changes header
                  if (state.currentStateType != state.nextStateType) ...<Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.swap_horiz, color: Colors.blue.shade700, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'State Type Changed',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${state.currentStateType} → ${state.nextStateType}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Old State Section
                  _buildStateSection(
                    'Previous State',
                    state.currentState?.toString() ?? 'null',
                    Colors.red.shade700,
                    Colors.red.shade50,
                    Colors.red.shade100,
                    Icons.remove_circle_outline,
                  ),

                  const SizedBox(height: 16),

                  // New State Section
                  _buildStateSection(
                    'Current State',
                    state.nextState?.toString() ?? 'null',
                    Colors.green.shade700,
                    Colors.green.shade50,
                    Colors.green.shade100,
                    Icons.add_circle_outline,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton.icon(
              onPressed: () async {
                final String copyText = 'Previous State:\n${state.currentState?.toString() ?? 'null'}\n\n'
                    'Current State:\n${state.nextState?.toString() ?? 'null'}';
                await Clipboard.setData(ClipboardData(text: copyText));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Full states copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('Copy Both'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Build a beautiful state section for the dialog
  Widget _buildStateSection(
    String title,
    String content,
    Color titleColor,
    Color backgroundColor,
    Color buttonColor,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: titleColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with title and copy button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: titleColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, color: titleColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: content));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$title copied to clipboard'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: buttonColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.copy, size: 14, color: titleColor),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            color: titleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content area with formatted state
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _beautifyStateString(content),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Beautify state string with proper formatting
  String _beautifyStateString(String stateString) {
    if (stateString == 'null') return 'null';

    try {
      // Try to format if it looks like a structured object
      if (stateString.contains('(') && stateString.contains(':')) {
        return _formatStructuredString(stateString);
      }

      // Return as-is if not structured
      return stateString;
    } on Exception catch (_) {
      // If formatting fails, return original
      return stateString;
    }
  }

  /// Format structured strings like ClassName(field: value, field2: value2)
  String _formatStructuredString(String input) {
    final String formatted = input;

    // Add line breaks after commas (except those inside nested objects)
    int depth = 0;
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < formatted.length; i++) {
      final String char = formatted[i];

      if (char == '(' || char == '[' || char == '{') {
        buffer.write(char);
        depth++;
        if (depth == 1) {
          buffer.write('\n');
          buffer.write('  ' * depth);
        }
      } else if (char == ')' || char == ']' || char == '}') {
        if (depth == 1) {
          buffer.write('\n');
        }
        depth--;
        buffer.write(char);
      } else if (char == ',' && depth > 0) {
        buffer.write(char);
        if (i + 1 < formatted.length && formatted[i + 1] == ' ') {
          buffer.write('\n');
          buffer.write('  ' * depth);
          i++; // Skip the space after comma
        }
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// Show detailed diff information in a dialog
  void _showDiffDialog(StateDiff diff) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: <Widget>[
              Icon(
                diff.changeType == StateDiffType.added
                    ? Icons.add
                    : diff.changeType == StateDiffType.removed
                        ? Icons.remove
                        : Icons.edit,
                size: 20,
                color: diff.changeType == StateDiffType.added
                    ? Colors.green.shade700
                    : diff.changeType == StateDiffType.removed
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diff.fieldName,
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (diff.changeType == StateDiffType.modified) ...<Widget>[
                  Text(
                    'Old Value:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      diff.oldValue,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'New Value:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      diff.newValue,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (diff.changeType == StateDiffType.added) ...<Widget>[
                  Text(
                    'Added Value:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      diff.newValue,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (diff.changeType == StateDiffType.removed) ...<Widget>[
                  Text(
                    'Removed Value:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      diff.oldValue,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                final String copyText = diff.changeType == StateDiffType.modified
                    ? 'Field: ${diff.fieldName}\nOld: ${diff.oldValue}\nNew: ${diff.newValue}'
                    : diff.changeType == StateDiffType.added
                        ? 'Field: ${diff.fieldName}\nAdded: ${diff.newValue}'
                        : 'Field: ${diff.fieldName}\nRemoved: ${diff.oldValue}';

                await Clipboard.setData(ClipboardData(text: copyText));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Diff details copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Truncate long values for better display
  String _truncateValue(String value) {
    const int maxLength = 80; // Reduced to prevent overflow issues
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  /// Attempt to extract field information from objects using common patterns
  Map<String, dynamic> _tryExtractFields(Object obj) {
    final Map<String, dynamic> result = <String, dynamic>{};

    try {
      // Try to access common getter patterns
      final String objString = obj.toString();

      // Look for patterns like "ClassName(field1: value1, field2: value2)" or freezed patterns
      final RegExp pattern = RegExp(r'(\w+):\s*([^,)}\]]+)');
      final Iterable<RegExpMatch> matches = pattern.allMatches(objString);

      for (final RegExpMatch match in matches) {
        if (match.groupCount >= 2) {
          final String key = match.group(1)!;
          final String value = match.group(2)!.trim();
          result[key] = value;
        }
      }

      // Limit the number of fields to avoid overwhelming display
      if (result.length > 5) {
        final Map<String, dynamic> limited = <String, dynamic>{};
        final List<String> keys = result.keys.take(5).toList();
        for (final String key in keys) {
          limited[key] = result[key];
        }
        limited['...'] = '${result.length - 5} more fields';
        return limited;
      }
    } on Exception catch (_) {
      // If parsing fails, return empty map
    }

    return result;
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  /// Format creation time with relative display (e.g., "Created 2m ago")
  String _formatCreationTime(DateTime? creationTime) {
    if (creationTime == null) return 'Creation time unknown';

    final DateTime now = DateTime.now();
    final Duration difference = now.difference(creationTime);

    if (difference.inDays > 0) {
      return 'Created ${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return 'Created ${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return 'Created ${difference.inMinutes}m ago';
    } else if (difference.inSeconds > 0) {
      return 'Created ${difference.inSeconds}s ago';
    } else {
      return 'Created just now';
    }
  }
}
