import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final soundServiceProvider = Provider((ref) => SoundService());

class SoundService {
  final AudioPlayer _player = AudioPlayer();
  final AssetSource _beepSource = AssetSource('sounds/beep.mp3');

  SoundService() {
    // Try to pre-set usage
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setSource(_beepSource);
    } catch (_) {}
  }

  Future<void> playBeep() async {
    try {
      await _player.stop();
      if (_player.source == null) {
        await _player.setSource(_beepSource);
      }
      await _player.play(_beepSource, mode: PlayerMode.lowLatency);
    } catch (e) {
      // Ignore audio errors
    }
  }

  void dispose() {
    _player.dispose();
  }
}
