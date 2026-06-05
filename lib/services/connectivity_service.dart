import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight connectivity monitor.
/// Exposes a stream and a sync getter for current connectivity state.
class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _isOnline;

  /// Start listening to connectivity changes.
  void init() {
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
    });
    // Seed initial state
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
    });
  }

  void dispose() {
    _sub?.cancel();
  }
}
