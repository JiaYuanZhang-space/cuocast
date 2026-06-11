import 'package:flutter/material.dart';
import 'package:wc_app/models/match.dart';

class MatchCard extends StatelessWidget {
  final Match match;
  const MatchCard(this.match, {super.key});

  String get _score => (match.homeScore == null || match.awayScore == null)
      ? 'VS'
      : '${match.homeScore} - ${match.awayScore}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(match.round ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(match.isLive ? "${match.minute}'" : match.status,
                style: TextStyle(fontSize: 12,
                    color: match.isLive ? Colors.red : Colors.grey)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(match.home, textAlign: TextAlign.start)),
            Text(_score, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Expanded(child: Text(match.away, textAlign: TextAlign.end)),
          ]),
        ]),
      ),
    );
  }
}
