import 'package:flutter_riverpod/flutter_riverpod.dart';

final loginGuardProvider = Provider<LoginGuardService>((ref) {
  return LoginGuardService();
});

class LoginGuardService {
  final Map<String, int> _failedAttempts = {};
  final Map<String, DateTime> _lockouts = {};

  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  bool isLockedOut(String identifier) {
    final lockoutTime = _lockouts[identifier];
    if (lockoutTime == null) return false;

    if (DateTime.now().isAfter(lockoutTime)) {
      _lockouts.remove(identifier);
      _failedAttempts.remove(identifier);
      return false;
    }
    return true;
  }

  void recordFailure(String identifier) {
    final attempts = (_failedAttempts[identifier] ?? 0) + 1;
    _failedAttempts[identifier] = attempts;

    if (attempts >= maxAttempts) {
      _lockouts[identifier] = DateTime.now().add(lockoutDuration);
    }
  }

  void reset(String identifier) {
    _failedAttempts.remove(identifier);
    _lockouts.remove(identifier);
  }

  String getRemainingLockoutTime(String identifier) {
    final lockoutTime = _lockouts[identifier];
    if (lockoutTime == null) return "0s";
    final remaining = lockoutTime.difference(DateTime.now());
    return "${remaining.inMinutes}m ${remaining.inSeconds % 60}s";
  }
}
