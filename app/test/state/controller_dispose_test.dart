import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/fixtures_controller.dart';
import 'package:wc_app/state/odds_controller.dart';

Future<Repository> _repo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Repository(
    api: ApiClient(
        baseUrl: 'http://x',
        httpClient: MockClient(
            (r) async => http.Response('{"data":[],"stale":false}', 200))),
    cache: LocalCache(prefs),
  );
}

void main() {
  test('FixturesController.load after dispose does not throw', () async {
    final c = FixturesController(await _repo());
    final f = c.load(); // in flight
    c.dispose();
    await f; // completes after dispose; must not throw "used after disposed"
  });

  test('OddsController.load after dispose does not throw', () async {
    final c = OddsController(await _repo());
    final f = c.load(101);
    c.dispose();
    await f;
  });
}
