import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/local_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('returns null when nothing stored', () async {
    final cache = LocalCache(await SharedPreferences.getInstance());
    expect(cache.read('fixtures'), isNull);
  });

  test('write then read returns same json string', () async {
    final cache = LocalCache(await SharedPreferences.getInstance());
    await cache.write('fixtures', '{"data":[],"stale":false}');
    expect(cache.read('fixtures'), '{"data":[],"stale":false}');
  });
}
