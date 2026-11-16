import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class BackupService {
  BackupService._privateConstructor();
  static final BackupService instance = BackupService._privateConstructor();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<File?> createBackupFile() async {
    try {
      final data = await _dbHelper.exportBackupData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final fileName = 'ExpenseTracker_Backup_$timestamp.json';
      final file = File(p.join(tempDir.path, fileName));

      await file.writeAsString(jsonString, flush: true);
      return file;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }

  Future<bool> shareBackupFile() async {
    final file = await createBackupFile();
    if (file != null && await file.exists()) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Expense Tracker Backup',
          text: 'Backup file for Shake Expense Tracker.',
        ),
      );
      return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
    }
    return false;
  }

  Future<bool> restoreFromBackupFile(File file) async {
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;

      if (!decoded.containsKey('expenses') || !decoded.containsKey('categories')) {
        return false;
      }

      await _dbHelper.restoreBackupData(decoded);
      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }
}
