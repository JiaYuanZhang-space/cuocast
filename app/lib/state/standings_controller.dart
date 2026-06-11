import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/standing.dart';

class StandingsController extends ChangeNotifier {
  final Repository _repo;
  StandingsController(this._repo);

  bool _disposed = false;
  bool loading = false;
  Object? error;
  List<Standing>? standings;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    error = null;
    if (!_disposed) notifyListeners();
    try {
      final res = await _repo.fetchStandings();
      standings = res.data;
      stale = res.stale;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
