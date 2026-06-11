class Standing {
  final int rank;
  final String team;
  final int played, win, draw, lose, goalsDiff, points;

  Standing({required this.rank, required this.team, required this.played,
      required this.win, required this.draw, required this.lose,
      required this.goalsDiff, required this.points});

  factory Standing.fromJson(Map<String, dynamic> json) => Standing(
        rank: json['rank'] as int,
        team: json['team'] as String,
        played: json['played'] as int,
        win: json['win'] as int,
        draw: json['draw'] as int,
        lose: json['lose'] as int,
        goalsDiff: json['goalsDiff'] as int,
        points: json['points'] as int,
      );
}
