import 'package:audioplayers/audioplayers.dart';

/// Reproductor del "pling" de logro. Fail-safe: si el audio no está
/// disponible (p. ej. en tests) simplemente no suena.
class AchievementSound {
  AchievementSound._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/achievement.wav'));
    } catch (_) {
      // sin audio disponible
    }
  }
}
