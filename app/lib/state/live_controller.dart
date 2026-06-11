import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/match.dart';

class LiveController extends ChangeNotifier {
  final Repository _repo;
  final Duration interval;
  Timer? _timer;
  bool _disposed = false;

  LiveController(this._repo, {this.interval = const Duration(seconds: 30)});

  bool loading = false;
  Object? error;
  List<Match>? matches;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    if (!_disposed) notifyListeners();
    try {
      final res = await _repo.fetchLive();
      matches = res.data;
      stale = res.stale;
      error = null;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void startPolling() {
    load();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => load());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
