import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'google_auth_service.dart';
import 'backup_result.dart';

enum BackupStatus { idle, loading, success, error }

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(googleAuthServiceProvider));
});

class BackupService {
  final GoogleAuthService _authService;

  BackupService(this._authService);

  Future<String> _getDbPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final newPath = p.join(directory.path, 'kasirku.sqlite');
    final oldPath = p.join(directory.path, 'kasir_offline.sqlite');

    // Migration: If old file exists and new doesn't, rename it
    if (await File(oldPath).exists() && !(await File(newPath).exists())) {
      await File(oldPath).rename(newPath);
    }

    return newPath;
  }

  Future<BackupResult?> _preflightCheck() async {
    // 1. Check Connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return const BackupNoInternet();
    }

    // 2. Practical internet check (can we reach Google?)
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return const BackupNoInternet();
    } catch (_) {
      return const BackupNoInternet();
    }

    // 3. Check Auth
    final client = await _authService.getHttpClient();
    if (client == null) {
      return const BackupNotAuthenticated();
    }

    // 4. Check Database File
    final dbPath = await _getDbPath();
    if (!await File(dbPath).exists()) {
      return const BackupFileNotFound();
    }

    return null; // All good
  }

  Future<BackupResult> uploadBackup() async {
    final preflight = await _preflightCheck();
    if (preflight != null) return preflight;

    final client = await _authService
        .getHttpClient(); // Guaranteed non-null by preflight
    final driveApi = drive.DriveApi(client!);
    final dbPath = await _getDbPath();
    final file = File(dbPath);

    final media = drive.Media(file.openRead(), await file.length());

    try {
      final list = await driveApi.files.list(
        q: "name = 'kasirku_backup.sqlite' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
      );

      if (list.files != null && list.files!.isNotEmpty) {
        // Update: Don't set parents on update, it's already there
        final updateFile = drive.File();
        updateFile.name =
            'kasirku_backup.sqlite'; // Name should still be set for update
        await driveApi.files.update(
          updateFile,
          list.files!.first.id!,
          uploadMedia: media,
        );
      } else {
        // Create: Set parents to appDataFolder
        final driveFile = drive.File();
        driveFile.name = 'kasirku_backup.sqlite';
        driveFile.parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
      }
      return BackupSuccess(DateTime.now());
    } catch (e) {
      return BackupDriveError(e.toString());
    }
  }

  Future<BackupResult> restoreBackup() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return const BackupNoInternet();
    }

    final client = await _authService.getHttpClient();
    if (client == null) return const BackupNotAuthenticated();

    final driveApi = drive.DriveApi(client);

    try {
      final list = await driveApi.files.list(
        q: "name = 'kasirku_backup.sqlite' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
      );

      if (list.files == null || list.files!.isEmpty) {
        return const BackupError('Cadangan tidak ditemukan di Google Drive.');
      }

      final fileId = list.files!.first.id!;
      final media =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final dbPath = await _getDbPath();
      final file = File(dbPath);
      final List<int> data = [];
      await for (final chunk in media.stream) {
        data.addAll(chunk);
      }

      await file.writeAsBytes(data);
      return BackupSuccess(DateTime.now());
    } catch (e) {
      return BackupDriveError(e.toString());
    }
  }
}
