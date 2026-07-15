import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';
import '../interfaces/services.dart';

final _log = Logger('NetworkService');

class NetworkService implements INetworkService {
  final Connectivity _connectivity = Connectivity();
  final _statusController = StreamController<bool>.broadcast();
  @override
  Stream<bool> get statusStream => _statusController.stream;

  bool _isOnline = true;
  @override
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void init() {
    _checkStatus();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _isOnline = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.mobile);
      _statusController.add(_isOnline);
      _log.info('network status: ${_isOnline ? "online" : "offline"}');
    });
  }

  Future<void> _checkStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.mobile);
      _statusController.add(_isOnline);
    } catch (e) {
      _log.warning('connectivity check failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
