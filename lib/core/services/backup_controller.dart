import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'backup_service.dart';
import 'backup_result.dart';

enum BackupStatus { idle, loading, success, error }

class BackupState {
  final BackupStatus status;
  final String? errorMessage;
  final String? technicalDetails;
  final DateTime? lastActionTime;

  BackupState({
    required this.status,
    this.errorMessage,
    this.technicalDetails,
    this.lastActionTime,
  });

  factory BackupState.initial() => BackupState(status: BackupStatus.idle);

  BackupState copyWith({
    BackupStatus? status,
    String? errorMessage,
    String? technicalDetails,
    DateTime? lastActionTime,
  }) {
    return BackupState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      technicalDetails: technicalDetails ?? this.technicalDetails,
      lastActionTime: lastActionTime ?? this.lastActionTime,
    );
  }
}

final backupControllerProvider =
    StateNotifierProvider<BackupController, BackupState>((ref) {
      final service = ref.watch(backupServiceProvider);
      return BackupController(service);
    });

class BackupController extends StateNotifier<BackupState> {
  final BackupService _service;

  BackupController(this._service) : super(BackupState.initial());

  Future<void> runBackup() async {
    if (state.status == BackupStatus.loading) return;

    state = state.copyWith(status: BackupStatus.loading, errorMessage: null);

    final result = await _service.uploadBackup();

    if (result is BackupSuccess) {
      state = state.copyWith(
        status: BackupStatus.success,
        lastActionTime: result.timestamp,
        errorMessage: null,
        technicalDetails: null,
      );
    } else if (result is BackupError) {
      state = state.copyWith(
        status: BackupStatus.error,
        errorMessage: result.message,
        technicalDetails: result.technicalDetails,
      );
    }
  }

  Future<void> runRestore() async {
    if (state.status == BackupStatus.loading) return;

    state = state.copyWith(
      status: BackupStatus.loading,
      errorMessage: null,
      technicalDetails: null,
    );

    final result = await _service.restoreBackup();

    if (result is BackupSuccess) {
      state = state.copyWith(
        status: BackupStatus.success,
        lastActionTime: result.timestamp,
        errorMessage: null,
        technicalDetails: null,
      );
    } else if (result is BackupError) {
      state = state.copyWith(
        status: BackupStatus.error,
        errorMessage: result.message,
        technicalDetails: result.technicalDetails,
      );
    }
  }

  void resetStatus() {
    state = state.copyWith(status: BackupStatus.idle);
  }
}
