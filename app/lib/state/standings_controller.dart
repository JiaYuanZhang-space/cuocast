import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/standing.dart';

class StandingsController extends ChangeNotifier {
  final Repository _repo;
  StandingsController(this._repo);

  bool loading = false;
  Object? error;
  List<Standing>? standings;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.fetchStandings();
      standings = res.data;
      stale = res.stale;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
