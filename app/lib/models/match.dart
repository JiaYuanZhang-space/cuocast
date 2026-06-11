class Match {
  final int id;
  final String kickoff;
  final String status;
  final int? minute;
  final String? venue;
  final String? round;
  final String home;
  final String away;
  final int? homeScore;
  final int? awayScore;

  Match({
    required this.id, required this.kickoff, required this.status,
    this.minute, this.venue, this.round, required this.home,
    required this.away, this.homeScore, this.awayScore,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'] as int,
        kickoff: json['kickoff'] as String,
        status: json['status'] as String,
        minute: json['minute'] as int?,
        venue: json['venue'] as String?,
        round: json['round'] as String?,
        home: json['home'] as String,
        away: json['away'] as String,
        homeScore: json['homeScore'] as int?,
        awayScore: json['awayScore'] as int?,
      );

  bool get isLive => status == '1H' || status == '2H' || status == 'HT' || status == 'ET';
}
