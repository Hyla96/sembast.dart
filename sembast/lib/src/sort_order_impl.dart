import 'package:sembast/sembast.dart';
import 'package:sembast/src/boundary_impl.dart';
import 'package:sembast/src/utils.dart';

/// Sort order implementation.
class SembastSortOrder implements SortOrder {
  /// ascending.
  final bool ascending; // default true
  /// field (key) name.
  final String field;

  /// null last.
  final bool nullLast; // default false

  ///
  /// default is [ascending] = true, [nullLast] = false
  ///
  /// user withParam
  SembastSortOrder(this.field, [bool? ascending, bool? nullLast])
      : ascending = ascending != false,
        nullLast = nullLast == true;

  /// Compare 2 record.
  int compare(RecordSnapshot record1, RecordSnapshot record2) {
    final result = compareAscending(record1, record2);
    return ascending ? result : -result;
  }

  /// Compare a record to a boundary.
  int compareToBoundary(RecordSnapshot record, Boundary boundary, int index) {
    final result = compareToBoundaryAscending(record, boundary, index);
    return ascending ? result : -result;
  }

  /// Compare a record to a snapshot.
  int compareToSnapshotAscending(
      RecordSnapshot record, RecordSnapshot snapshot) {
    var value1 = record[field];
    var value2 = snapshot[field];
    return compareValueAscending(value1, value2);
  }

  /// Compare a record to a boundary in ascending order.
  int compareToBoundaryAscending(
      RecordSnapshot record, Boundary boundary, int index) {
    final sembastBoundary = boundary as SembastBoundary;
    if (sembastBoundary.values != null) {
      var value = sembastBoundary.values![index];
      return compareValueAscending(record[field], value);
    } else if (sembastBoundary.snapshot != null) {
      return compareToSnapshotAscending(record, sembastBoundary.snapshot!);
    }
    throw ArgumentError('either record or values must be provided');
  }

  /// Compare 2 records in ascending order.
  int compareAscending(RecordSnapshot record1, RecordSnapshot record2) {
    var value1 = record1[field];
    var value2 = record2[field];
    return compareValueAscending(value1, value2);
  }

  /// Compare 2 values in ascending order.
  int compareValueAscending(dynamic value1, dynamic value2) {
    if (value1 == null) {
      if (value2 == null) {
        return 0;
      }
      if (nullLast) {
        return 1;
      } else {
        return -1;
      }
    } else if (value2 == null) {
      if (nullLast) {
        return -1;
      } else {
        return 1;
      }
    }
    return compareValue(value1, value2);
  }

  Map<String, Object?> _toDebugMap() {
    final map = <String, Object?>{
      field: ascending ? 'asc' : 'desc',
      if (nullLast == true) 'nullLast': true
    };
    return map;
  }

  @override
  String toString() {
    return _toDebugMap().toString();
  }
}
