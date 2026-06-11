import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/ui/home_scaffold.dart';

Future<Repository> _repo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Repository(
    api: ApiClient(baseUrl: 'http://x',
        httpClient: MockClient((r) async => http.Response('{"data":[],"stale":false}', 200))),
    cache: LocalCache(prefs));
}

void main() {
  testWidgets('home shows 5 bottom nav destinations', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScaffold(repository: await _repo())));
    await tester.pump();
    expect(find.text('赛程'), findsWidgets);
    expect(find.text('赔率'), findsWidgets);
    // teardown: dispose tree so LiveScreen polling timer is cancelled
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('tapping 赔率 switches selected index', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScaffold(repository: await _repo())));
    await tester.pump();
    await tester.tap(find.text('赔率'));
    await tester.pump();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
