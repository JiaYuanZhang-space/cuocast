class MatchEvent {
  final int minute;
  final String team;
  final String? player;
  final String type;
  final String? detail;

  MatchEvent({required this.minute, required this.team, this.player,
      required this.type, this.detail});

  factory MatchEvent.fromJson(Map<String, dynamic> json) => MatchEvent(
        minute: json['minute'] as int,
        team: json['team'] as String,
        player: json['player'] as String?,
        type: json['type'] as String,
        detail: json['detail'] as String?,
      );
}
