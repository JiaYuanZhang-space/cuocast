import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/fixtures_controller.dart';
import 'package:wc_app/ui/fixtures_screen.dart';

const _body = '{"data":[{"id":1,"kickoff":"x","status":"NS","minute":null,'
    '"venue":null,"round":"Group A","home":"Brazil","away":"Germany",'
    '"homeScore":null,"awayScore":null}],"stale":false}';

void main() {
  testWidgets('shows fixtures after load', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_body, 200))),
      cache: LocalCache(prefs));
    final controller = FixturesController(repo);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FixturesScreen(controller: controller))));
    await tester.pumpAndSettle();
    expect(find.text('Brazil'), findsOneWidget);
    expect(find.text('Germany'), findsOneWidget);
  });
}
