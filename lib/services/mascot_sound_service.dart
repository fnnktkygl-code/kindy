import 'package:audioplayers/audioplayers.dart';

/// Lightweight sound service for mascot interaction feedback.
/// Uses AudioPlayer pools to avoid creation overhead and handles
/// overlapping sounds gracefully.
class MascotSoundService {
  MascotSoundService._();
  static final MascotSoundService _instance = MascotSoundService._();
  static MascotSoundService get instance => _instance;

  bool muted = false;

  void setEnabled(bool enabled) {
    muted = !enabled;
  }

  // Pre-created players for low-latency playback
  AudioPlayer _tapPlayer = AudioPlayer();
  AudioPlayer _popPlayer = AudioPlayer();
  AudioPlayer _whooshPlayer = AudioPlayer();
  AudioPlayer _gigglePlayer = AudioPlayer();

  bool _initialized = false;
  bool _disposed = false;

  Future<void> init() async {
    if (_initialized && !_disposed) return;
    if (_disposed) {
      // Re-create players after a prior dispose (e.g. hot restart)
      _tapPlayer = AudioPlayer();
      _popPlayer = AudioPlayer();
      _whooshPlayer = AudioPlayer();
      _gigglePlayer = AudioPlayer();
      _disposed = false;
    }
    _initialized = true;
    // Set low volume for subtlety
    await _tapPlayer.setVolume(0.3);
    await _popPlayer.setVolume(0.25);
    await _whooshPlayer.setVolume(0.2);
    await _gigglePlayer.setVolume(0.35);
  }

  /// Short chirp on tap
  Future<void> playTap() async {
    if (muted || _disposed) return;
    await _tapPlayer.stop();
    await _tapPlayer.play(AssetSource('sounds/chirp.wav'));
  }

  /// Bubble pop when speech bubble appears
  Future<void> playPop() async {
    if (muted || _disposed) return;
    await _popPlayer.stop();
    await _popPlayer.play(AssetSource('sounds/pop.wav'));
  }

  /// Soft whoosh on drag release
  Future<void> playWhoosh() async {
    if (muted || _disposed) return;
    await _whooshPlayer.stop();
    await _whooshPlayer.play(AssetSource('sounds/whoosh.wav'));
  }

  /// Tickle giggle on rapid taps
  Future<void> playGiggle() async {
    if (muted || _disposed) return;
    await _gigglePlayer.stop();
    await _gigglePlayer.play(AssetSource('sounds/giggle.wav'));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _tapPlayer.dispose();
    _popPlayer.dispose();
    _whooshPlayer.dispose();
    _gigglePlayer.dispose();
  }
}
