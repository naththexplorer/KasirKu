import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final soundServiceProvider = Provider((ref) => SoundService());

class SoundService {
  final AudioPlayer _player = AudioPlayer();
  final AssetSource _beepSource = AssetSource('sounds/beep.mp3');

  SoundService() {
    // Pre-set the source for faster subsequent plays
    _player.setSource(_beepSource);
  }

  Future<void> playBeep() async {
    try {
      // stop() is essential to reset the playback for high-frequency calls
      await _player.stop();
      await _player.play(_beepSource, mode: PlayerMode.lowLatency);
    } catch (e) {
      // Ignore audio errors in production
    }
  }

  void dispose() {
    _player.dispose();
  }
}
