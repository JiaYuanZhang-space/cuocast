import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/match.dart';

class FixturesController extends ChangeNotifier {
  final Repository _repo;
  FixturesController(this._repo);

  bool loading = false;
  Object? error;
  List<Match>? matches;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.fetchFixtures();
      matches = res.data;
      stale = res.stale;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
