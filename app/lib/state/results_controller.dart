import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/match.dart';

class ResultsController extends ChangeNotifier {
  final Repository _repo;
  ResultsController(this._repo);

  bool loading = false;
  Object? error;
  List<Match>? matches;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.fetchResults();
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
