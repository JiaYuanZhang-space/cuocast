import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/live_controller.dart';

const _body = '{"data":[],"stale":false}';

void main() {
  test('load fetches live matches', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async {
        calls++;
        return http.Response(_body, 200);
      })),
      cache: LocalCache(prefs));
    final c = LiveController(repo, interval: const Duration(milliseconds: 20));
    await c.load();
    expect(calls, 1);
    expect(c.matches, isNotNull);
  });

  test('startPolling triggers repeated loads then stops on dispose', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async {
        calls++;
        return http.Response(_body, 200);
      })),
      cache: LocalCache(prefs));
    final c = LiveController(repo, interval: const Duration(milliseconds: 20));
    c.startPolling();
    await Future.delayed(const Duration(milliseconds: 70));
    c.dispose();
    final afterDispose = calls;
    await Future.delayed(const Duration(milliseconds: 50));
    expect(afterDispose, greaterThanOrEqualTo(3));
    expect(calls, afterDispose);
  });
}
