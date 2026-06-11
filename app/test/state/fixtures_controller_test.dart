import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/fixtures_controller.dart';

const _body = '{"data":[{"id":1,"kickoff":"x","status":"NS","minute":null,'
    '"venue":null,"round":"r","home":"A","away":"B","homeScore":null,"awayScore":null}],'
    '"stale":false}';

Future<Repository> repo(MockClient m) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Repository(api: ApiClient(baseUrl: 'http://x', httpClient: m), cache: LocalCache(prefs));
}

void main() {
  test('load sets matches and clears loading', () async {
    final c = FixturesController(await repo(MockClient((r) async => http.Response(_body, 200))));
    expect(c.loading, false);
    final f = c.load();
    expect(c.loading, true);
    await f;
    expect(c.loading, false);
    expect(c.matches!.length, 1);
    expect(c.error, isNull);
  });

  test('load captures error when no data', () async {
    final c = FixturesController(await repo(MockClient((r) async => http.Response('e', 502))));
    await c.load();
    expect(c.matches, isNull);
    expect(c.error, isNotNull);
  });
}
