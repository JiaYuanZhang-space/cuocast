import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/odds_controller.dart';

const _body = '{"data":{"wdl":{"home":1.95,"draw":3.4,"away":3.75}},"stale":false}';
const _nullBody = '{"data":null,"stale":true}';

void main() {
  test('load parses wdl odds', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_body, 200))),
      cache: LocalCache(prefs));
    final c = OddsController(repo);
    await c.load(101);
    expect(c.odds!.wdl!.home, 1.95);
  });

  test('load handles null odds (unavailable)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_nullBody, 200))),
      cache: LocalCache(prefs));
    final c = OddsController(repo);
    await c.load(101);
    expect(c.odds!.wdl, isNull);
    expect(c.error, isNull);
  });
}
