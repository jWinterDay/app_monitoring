/// Data class representing a memory leak location with detailed information
/// Applies TRIZ UNIVERSALITY: standardized leak location representation
class LeakLocation {
  const LeakLocation({
    required this.objectType,
    required this.objectId,
    required this.filePath,
    required this.lineNumber,
    required this.stackTrace,
    required this.creationLocation,
  });

  final String objectType;
  final String objectId;
  final String filePath;
  final int lineNumber;
  final List<String> stackTrace;
  final String creationLocation;

  /// Creates a copy of this leak location with updated fields
  LeakLocation copyWith({
    String? objectType,
    String? objectId,
    String? filePath,
    int? lineNumber,
    List<String>? stackTrace,
    String? creationLocation,
  }) {
    return LeakLocation(
      objectType: objectType ?? this.objectType,
      objectId: objectId ?? this.objectId,
      filePath: filePath ?? this.filePath,
      lineNumber: lineNumber ?? this.lineNumber,
      stackTrace: stackTrace ?? this.stackTrace,
      creationLocation: creationLocation ?? this.creationLocation,
    );
  }

  @override
  String toString() {
    return 'LeakLocation(objectType: $objectType, objectId: $objectId, '
        'filePath: $filePath, lineNumber: $lineNumber, '
        'stackFrames: ${stackTrace.length}, creationLocation: $creationLocation)';
  }
}
