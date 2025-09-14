import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Small widget to display SQL database file size
/// Follows TRIZ principles: SEGMENTATION (focused on database monitoring),
/// LOCAL QUALITY (optimized for storage info), PRIOR COUNTERACTION (handles missing files)
class DatabaseSizeMonitor extends StatefulWidget {
  const DatabaseSizeMonitor({
    required this.databasePath,
    super.key,
  });
  final String databasePath;

  @override
  State<DatabaseSizeMonitor> createState() => _DatabaseSizeMonitorState();
}

class _DatabaseSizeMonitorState extends State<DatabaseSizeMonitor> {
  Timer? _sizeTimer;
  double _databaseSizeMB = 0.0;
  bool _databaseExists = false;
  String _lastUpdated = '';
  String _databaseName = '';

  static const Duration _updateInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _startSizeMonitoring();
  }

  @override
  void dispose() {
    _sizeTimer?.cancel();
    super.dispose();
  }

  void _startSizeMonitoring() {
    _updateDatabaseSize();
    _sizeTimer = Timer.periodic(_updateInterval, (Timer timer) {
      _updateDatabaseSize();
    });
  }

  Future<void> _updateDatabaseSize() async {
    if (!mounted) return;

    try {
      final File dbFile = File(widget.databasePath);

      setState(() {
        _databaseExists = dbFile.existsSync();
        if (_databaseExists) {
          final int sizeBytes = dbFile.lengthSync();
          _databaseSizeMB = sizeBytes / (1024 * 1024);
        } else {
          _databaseSizeMB = 0.0;
        }
        // Extract database name from full path for display
        _databaseName = p.basename(widget.databasePath);
        _lastUpdated = DateTime.now().toLocal().toString().substring(11, 19);
      });
    } on Exception catch (e) {
      debugPrint('Database size monitoring error: $e');
      setState(() {
        _databaseExists = false;
        _databaseSizeMB = 0.0;
        _databaseName = 'unknown.db';
      });
    }
  }

  String _formatSize() {
    if (_databaseSizeMB < 0.001) {
      return '${(_databaseSizeMB * 1024).toStringAsFixed(1)}KB';
    } else if (_databaseSizeMB < 1.0) {
      return '${(_databaseSizeMB * 1024).toStringAsFixed(0)}KB';
    } else {
      return '${_databaseSizeMB.toStringAsFixed(2)}MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.storage,
            color: _databaseExists ? Colors.green : Colors.grey.shade600,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Database Size',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Text(
                      _databaseExists ? _formatSize() : 'No DB',
                      style: textTheme.titleMedium?.copyWith(
                        color: _databaseExists ? Colors.black87 : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _databaseExists ? Colors.green : Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _databaseExists ? 'ACTIVE' : 'MISSING',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _databaseName.isNotEmpty ? _databaseName : 'info.db',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _lastUpdated,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
