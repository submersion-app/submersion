import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../database/database.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  AppDatabase? _database;

  AppDatabase get database {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  /// For testing only: allows injecting a test database
  @visibleForTesting
  void setTestDatabase(AppDatabase db) {
    _database = db;
  }

  /// For testing only: resets the database instance
  @visibleForTesting
  void resetForTesting() {
    _database = null;
  }

  Future<void> initialize() async {
    if (_database != null) return;

    final dbFolder = await getApplicationDocumentsDirectory();
    final submersionDir = Directory(p.join(dbFolder.path, 'Submersion'));

    if (!await submersionDir.exists()) {
      await submersionDir.create(recursive: true);
    }

    final file = File(p.join(submersionDir.path, 'submersion.db'));

    _database = AppDatabase(NativeDatabase.createInBackground(file));
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<String> get databasePath async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'Submersion', 'submersion.db');
  }

  Future<void> backup(String destinationPath) async {
    final sourcePath = await databasePath;
    final sourceFile = File(sourcePath);

    if (await sourceFile.exists()) {
      await sourceFile.copy(destinationPath);
    }
  }

  Future<void> restore(String backupPath) async {
    await close();

    final backupFile = File(backupPath);
    final destinationPath = await databasePath;

    if (await backupFile.exists()) {
      await backupFile.copy(destinationPath);
    }

    await initialize();
  }
}