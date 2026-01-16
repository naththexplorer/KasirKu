sealed class BackupResult {
  const BackupResult();
}

class BackupSuccess extends BackupResult {
  final DateTime timestamp;
  const BackupSuccess(this.timestamp);
}

class BackupError extends BackupResult {
  final String message;
  final String? technicalDetails;
  const BackupError(this.message, {this.technicalDetails});
}

class BackupNoInternet extends BackupError {
  const BackupNoInternet()
    : super('Tidak ada koneksi internet. Pastikan Anda terhubung ke jaringan.');
}

class BackupNotAuthenticated extends BackupError {
  const BackupNotAuthenticated()
    : super('Sesi Google berakhir atau belum masuk. Silakan login kembali.');
}

class BackupFileNotFound extends BackupError {
  const BackupFileNotFound()
    : super('File database tidak ditemukan. Periksa penyimpanan perangkat.');
}

class BackupDriveError extends BackupError {
  const BackupDriveError(String details)
    : super('Gagal mengakses Google Drive.', technicalDetails: details);
}
