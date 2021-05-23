import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:synchronized/synchronized.dart';

/// Open options.
class DatabaseOpenOptions {
  /// version.
  final int? version;

  /// open callback.
  final OnVersionChangedFunction? onVersionChanged;

  /// open mode.
  final DatabaseMode? mode;

  /// codec.
  final SembastCodec? codec;

  /// Open options.
  DatabaseOpenOptions({
    this.version,
    this.onVersionChanged,
    this.mode,
    this.codec,
  });

  @override
  String toString() {
    var map = <String, Object?>{};
    if (version != null) {
      map['version'] = version;
    }
    if (mode != null) {
      map['mode'] = mode;
    }
    if (codec != null) {
      map['codec'] = codec;
    }
    return map.toString();
  }
}

/// Open helper.
class DatabaseOpenHelper {
  /// The factory.
  final SembastDatabaseFactory factory;

  /// The path.
  final String path;

  /// The open mode that change overtime (empty to defaults)
  DatabaseMode? openMode;

  /// The open options.
  final DatabaseOpenOptions options;

  /// The locker.
  final lock = Lock();

  /// The database.
  SembastDatabase? database;

  /// Open helper.
  DatabaseOpenHelper(this.factory, this.path, this.options) {
    /// Always set an open mode
    openMode ??= options.mode ?? DatabaseMode.defaultMode;
  }

  /// Create a new database object.
  SembastDatabase newDatabase(String path) => factory.newDatabase(this);

  /// Open the database.
  Future<Database> openDatabase() {
    return lock.synchronized(() async {
      if (database == null) {
        final database = newDatabase(path);
        // Affect before open to properly clean
        this.database = database;
      }
      // Force helper again in case it was removed by lockedClose
      database!.openHelper = this;

      await database!.open(options);

      // Force helper again in case it was removed by lockedClose
      factory.setDatabaseOpenHelper(path, this);
      return database!;
    });
  }

  /// Closed the database.
  Future lockedCloseDatabase() async {
    if (database != null) {
      factory.removeDatabaseOpenHelper(path);
    }
    return database;
  }

  @override
  String toString() => 'DatabaseOpenHelper($path, $options)';
}

/// The factory implementation.
abstract class SembastDatabaseFactory implements DatabaseFactory {
  /// The actual implementation
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper);

  /// Delete a database.
  Future doDeleteDatabase(String path);

  /// Set the helper for a given path.
  void setDatabaseOpenHelper(String path, DatabaseOpenHelper helper);

  /// Remove the helper for a given path.
  void removeDatabaseOpenHelper(String path);
}

/// Database factory mixin.
mixin DatabaseFactoryMixin implements SembastDatabaseFactory {
  // for single instances only
  final _databaseOpenHelpers = <String, DatabaseOpenHelper>{};

  /// Open a database with a given set of options.
  Future<Database> openDatabaseWithOptions(
      String path, DatabaseOpenOptions options) {
    // Always specify the default codec
    var helper = getDatabaseOpenHelper(path, options);
    return helper.openDatabase();
  }

  @override
  Future<Database> openDatabase(String path,
      {int? version,
      OnVersionChangedFunction? onVersionChanged,
      DatabaseMode? mode,
      SembastCodec? codec}) {
    return openDatabaseWithOptions(
        path,
        DatabaseOpenOptions(
            version: version,
            onVersionChanged: onVersionChanged,
            mode: mode,
            codec: codec));
  }

  /// Get or create the open helper for a given path.
  DatabaseOpenHelper getDatabaseOpenHelper(
      String path, DatabaseOpenOptions options) {
    var helper = getExistingDatabaseOpenHelper(path);
    if (helper == null) {
      helper = DatabaseOpenHelper(this, path, options);
      setDatabaseOpenHelper(path, helper);
    }
    return helper;
  }

  /// Get existing open helper for a given path.
  DatabaseOpenHelper? getExistingDatabaseOpenHelper(String path) {
    return _databaseOpenHelpers[path];
  }

  @override
  void removeDatabaseOpenHelper(String path) {
    _databaseOpenHelpers.remove(path);
  }

  @override
  void setDatabaseOpenHelper(String path, DatabaseOpenHelper? helper) {
    _databaseOpenHelpers.remove(path);
    _databaseOpenHelpers[path] = helper!;
  }

  @override
  Future deleteDatabase(String path) async {
    // Close existing open instance
    var helper = getExistingDatabaseOpenHelper(path);
    if (helper != null && helper.database != null) {
      // Wait any pending open/close action
      await helper.lock.synchronized(() {
        return helper.lockedCloseDatabase();
      });
    }
    return doDeleteDatabase(path);
  }

  /// Flush all opened databases
  Future flush() async {
    var helpers = List<DatabaseOpenHelper>.from(_databaseOpenHelpers.values,
        growable: false);
    for (var helper in helpers) {
      await helper.database?.flush();
    }
  }
}
