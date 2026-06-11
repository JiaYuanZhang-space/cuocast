import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/results_controller.dart';

const _body = '{"data":[{"id":5,"kickoff":"x","status":"FT","minute":null,'
    '"venue":null,"round":"Group A","home":"NL","away":"EC",'
    '"homeScore":3,"awayScore":1}],"stale":false}';

void main() {
  test('load returns finished matches', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_body, 200))),
      cache: LocalCache(prefs));
    final c = ResultsController(repo);
    await c.load();
    expect(c.matches!.first.homeScore, 3);
    expect(c.error, isNull);
  });
}
