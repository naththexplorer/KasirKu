import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';

class SettingsState {
  final bool isSoundEnabled;

  SettingsState({this.isSoundEnabled = true});

  SettingsState copyWith({bool? isSoundEnabled}) {
    return SettingsState(isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled);
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref ref;
  static const _soundKey = 'is_sound_enabled';

  SettingsNotifier(this.ref) : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final prefs = ref.read(sharedPreferencesProvider);
    final isSoundEnabled = prefs.getBool(_soundKey) ?? true;
    state = SettingsState(isSoundEnabled: isSoundEnabled);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_soundKey, enabled);
    state = state.copyWith(isSoundEnabled: enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier(ref);
  },
);
