import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wc_app/data/api_client.dart';

void main() {
  test('getJson hits base+path and decodes body', () async {
    late Uri seen;
    final mock = MockClient((req) async {
      seen = req.url;
      return http.Response(jsonEncode({'data': [], 'stale': false}), 200);
    });
    final client = ApiClient(baseUrl: 'http://x:8000', httpClient: mock);
    final json = await client.getJson('/fixtures');
    expect(seen.toString(), 'http://x:8000/fixtures');
    expect(json['stale'], false);
  });

  test('getJson passes query params', () async {
    late Uri seen;
    final mock = MockClient((req) async {
      seen = req.url;
      return http.Response(jsonEncode({'data': null, 'stale': false}), 200);
    });
    final client = ApiClient(baseUrl: 'http://x:8000', httpClient: mock);
    await client.getJson('/odds', query: {'matchId': '101'});
    expect(seen.queryParameters['matchId'], '101');
  });

  test('getJson throws on non-200', () async {
    final mock = MockClient((req) async => http.Response('err', 502));
    final client = ApiClient(baseUrl: 'http://x:8000', httpClient: mock);
    expect(() => client.getJson('/fixtures'), throwsA(isA<ApiException>()));
  });
}
