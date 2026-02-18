import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;

  late AudioPlayer _audioPlayer;

  // Cache the source to avoid repeated object creation
  final AssetSource _keyPressSource =
      AssetSource('lib/assets/sounds/sound_2.mp3');

  AudioManager._internal() {
    _audioPlayer = AudioPlayer();
    _init();
  }

  void _init() async {
    // Set the prefix to empty to allow full path usage
    // This is crucial because the assets are in lib/assets/
    _audioPlayer.audioCache.prefix = '';

    // Set the mode to low latency if possible (platform dependent defaults usually work well for SFX)
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);

    // Preload the sound
    try {
      await _audioPlayer.audioCache.load('lib/assets/sounds/sound_2.mp3');
    } catch (e) {
      debugPrint("Error preloading sound: $e");
    }
  }

  /// Play the key press sound with minimal latency.
  /// This method is fire-and-forget and does not await the playback.
  void playKeyPressSound() {
    try {
      if (_audioPlayer.state == PlayerState.playing) {
        _audioPlayer.stop().then((_) {
          _audioPlayer.play(_keyPressSource, mode: PlayerMode.lowLatency);
        });
      } else {
        _audioPlayer.play(_keyPressSource, mode: PlayerMode.lowLatency);
      }
    } catch (e) {
      debugPrint("Error playing key press sound: $e");
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
