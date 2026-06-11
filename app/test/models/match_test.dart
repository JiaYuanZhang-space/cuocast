import 'package:flutter_test/flutter_test.dart';
import 'package:wc_app/models/match.dart';
import 'package:wc_app/models/api_response.dart';

void main() {
  test('Match.fromJson parses core fields', () {
    final m = Match.fromJson({
      'id': 101, 'kickoff': '2026-06-14T04:00:00+00:00', 'status': '1H',
      'minute': 23, 'venue': 'AT&T Stadium', 'round': 'Group Stage - 1',
      'home': 'Brazil', 'away': 'Germany', 'homeScore': 1, 'awayScore': 0,
    });
    expect(m.id, 101);
    expect(m.home, 'Brazil');
    expect(m.homeScore, 1);
    expect(m.minute, 23);
    expect(m.status, '1H');
  });

  test('Match.fromJson tolerates null score and minute', () {
    final m = Match.fromJson({
      'id': 9, 'kickoff': '2026-06-14T04:00:00+00:00', 'status': 'NS',
      'minute': null, 'venue': null, 'round': 'R16',
      'home': 'A', 'away': 'B', 'homeScore': null, 'awayScore': null,
    });
    expect(m.homeScore, isNull);
    expect(m.minute, isNull);
  });

  test('ApiResponse.fromJson wraps list with stale flag', () {
    final r = ApiResponse<List<Match>>.fromJson(
      {'data': [{'id': 1, 'kickoff': 'x', 'status': 'NS', 'minute': null,
                 'venue': null, 'round': 'r', 'home': 'A', 'away': 'B',
                 'homeScore': null, 'awayScore': null}], 'stale': true},
      (d) => (d as List).map((e) => Match.fromJson(e)).toList(),
    );
    expect(r.stale, true);
    expect(r.data.length, 1);
    expect(r.data.first.home, 'A');
  });
}
