import 'package:flutter_test/flutter_test.dart';
import 'package:wc_app/models/match_event.dart';
import 'package:wc_app/models/standing.dart';
import 'package:wc_app/models/odds.dart';

void main() {
  test('MatchEvent.fromJson', () {
    final e = MatchEvent.fromJson({
      'minute': 12, 'team': 'Brazil', 'player': 'Vinicius',
      'type': 'Goal', 'detail': 'Normal Goal'});
    expect(e.minute, 12);
    expect(e.type, 'Goal');
    expect(e.player, 'Vinicius');
  });

  test('Standing.fromJson', () {
    final s = Standing.fromJson({
      'rank': 1, 'team': 'Mexico', 'played': 2, 'win': 2, 'draw': 0,
      'lose': 0, 'goalsDiff': 3, 'points': 6});
    expect(s.rank, 1);
    expect(s.team, 'Mexico');
    expect(s.points, 6);
    expect(s.goalsDiff, 3);
  });

  test('Odds.fromJson with wdl', () {
    final o = Odds.fromJson({'wdl': {'home': 1.95, 'draw': 3.4, 'away': 3.75}});
    expect(o.wdl?.home, 1.95);
    expect(o.wdl?.draw, 3.4);
  });

  test('Odds.fromJson with null wdl', () {
    final o = Odds.fromJson({'wdl': null});
    expect(o.wdl, isNull);
  });
}
