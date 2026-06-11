class Wdl {
  final double home, draw, away;
  Wdl({required this.home, required this.draw, required this.away});
  factory Wdl.fromJson(Map<String, dynamic> j) => Wdl(
        home: (j['home'] as num).toDouble(),
        draw: (j['draw'] as num).toDouble(),
        away: (j['away'] as num).toDouble(),
      );
}

class Odds {
  final Wdl? wdl;
  Odds({this.wdl});
  factory Odds.fromJson(Map<String, dynamic> json) {
    final w = json['wdl'];
    return Odds(wdl: w == null ? null : Wdl.fromJson(w as Map<String, dynamic>));
  }
}
