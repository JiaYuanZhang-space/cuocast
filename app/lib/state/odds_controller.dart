import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/odds.dart';

class OddsController extends ChangeNotifier {
  final Repository _repo;
  OddsController(this._repo);

  bool loading = false;
  Object? error;
  Odds? odds;

  Future<void> load(int matchId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.fetchOdds(matchId);
      odds = res.data;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
