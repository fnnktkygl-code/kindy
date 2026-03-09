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
  final AudioPlayer _tapPlayer = AudioPlayer();
  final AudioPlayer _popPlayer = AudioPlayer();
  final AudioPlayer _whooshPlayer = AudioPlayer();
  final AudioPlayer _gigglePlayer = AudioPlayer();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Set low volume for subtlety
    await _tapPlayer.setVolume(0.3);
    await _popPlayer.setVolume(0.25);
    await _whooshPlayer.setVolume(0.2);
    await _gigglePlayer.setVolume(0.35);
  }

  /// Short chirp on tap
  Future<void> playTap() async {
    if (muted) return;
    await _tapPlayer.stop();
    await _tapPlayer.play(AssetSource('sounds/chirp.wav'));
  }

  /// Bubble pop when speech bubble appears
  Future<void> playPop() async {
    if (muted) return;
    await _popPlayer.stop();
    await _popPlayer.play(AssetSource('sounds/pop.wav'));
  }

  /// Soft whoosh on drag release
  Future<void> playWhoosh() async {
    if (muted) return;
    await _whooshPlayer.stop();
    await _whooshPlayer.play(AssetSource('sounds/whoosh.wav'));
  }

  /// Tickle giggle on rapid taps
  Future<void> playGiggle() async {
    if (muted) return;
    await _gigglePlayer.stop();
    await _gigglePlayer.play(AssetSource('sounds/giggle.wav'));
  }


  void dispose() {
    _tapPlayer.dispose();
    _popPlayer.dispose();
    _whooshPlayer.dispose();
    _gigglePlayer.dispose();
  }
}
