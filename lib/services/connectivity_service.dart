import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();

  Stream<bool> get onlineStream => _onlineController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateConnectivity(result);

    // Listen for connectivity changes
    _subscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectivity);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((result) => result != ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      debugPrint('Connectivity changed: ${_isOnline ? 'Online' : 'Offline'}');
      _onlineController.add(_isOnline);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }
}
