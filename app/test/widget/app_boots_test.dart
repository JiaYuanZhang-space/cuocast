import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/main.dart';

void main() {
  testWidgets('app boots and shows bottom nav', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WcApp());
    await tester.pump(); // resolve SharedPreferences future
    await tester.pump(); // build HomeScaffold
    expect(find.text('赛程'), findsWidgets);
    expect(find.text('赔率'), findsWidgets);
    // teardown: dispose tree so the live polling Timer.periodic is cancelled,
    // otherwise flutter_test fails with "A Timer is still pending".
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
