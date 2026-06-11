import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/standings_controller.dart';

const _body = '{"data":[{"rank":1,"team":"Mexico","played":2,"win":2,"draw":0,'
    '"lose":0,"goalsDiff":3,"points":6}],"stale":false}';

void main() {
  test('load returns standings sorted by rank', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_body, 200))),
      cache: LocalCache(prefs));
    final c = StandingsController(repo);
    await c.load();
    expect(c.standings!.first.team, 'Mexico');
    expect(c.standings!.first.points, 6);
  });
}
