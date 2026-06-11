import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';

Future<Repository> buildRepo(MockClient mock) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Repository(
    api: ApiClient(baseUrl: 'http://x:8000', httpClient: mock),
    cache: LocalCache(prefs),
  );
}

const _fixturesBody = '{"data":[{"id":1,"kickoff":"x","status":"NS","minute":null,'
    '"venue":null,"round":"r","home":"A","away":"B","homeScore":null,"awayScore":null}],'
    '"stale":false}';

void main() {
  test('fetchFixtures parses and returns matches', () async {
    final repo = await buildRepo(MockClient((req) async => http.Response(_fixturesBody, 200)));
    final res = await repo.fetchFixtures();
    expect(res.data.length, 1);
    expect(res.data.first.home, 'A');
    expect(res.stale, false);
  });

  test('fetchFixtures falls back to cache on error', () async {
    SharedPreferences.setMockInitialValues({'cache:fixtures': _fixturesBody});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x:8000',
          httpClient: MockClient((req) async => http.Response('err', 502))),
      cache: LocalCache(prefs),
    );
    final res = await repo.fetchFixtures();
    expect(res.data.first.home, 'A');
    expect(res.stale, true);
  });

  test('fetchFixtures rethrows when error and no cache', () async {
    final repo = await buildRepo(MockClient((req) async => http.Response('err', 502)));
    expect(() => repo.fetchFixtures(), throwsA(isA<ApiException>()));
  });
}
