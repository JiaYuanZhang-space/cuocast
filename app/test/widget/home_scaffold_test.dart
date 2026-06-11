import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wc_app/ui/home_scaffold.dart';

void main() {
  testWidgets('home shows 5 bottom nav destinations', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScaffold()));
    expect(find.text('赛程'), findsOneWidget);
    expect(find.text('实况'), findsOneWidget);
    expect(find.text('结果'), findsOneWidget);
    expect(find.text('积分'), findsOneWidget);
    expect(find.text('赔率'), findsOneWidget);
  });

  testWidgets('tapping 赔率 switches selected index', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScaffold()));
    await tester.tap(find.text('赔率'));
    await tester.pumpAndSettle();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);
  });
}
