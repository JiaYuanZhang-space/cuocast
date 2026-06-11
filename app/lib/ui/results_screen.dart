import 'package:flutter/material.dart';
import 'package:wc_app/models/match.dart';
import 'package:wc_app/state/results_controller.dart';
import 'package:wc_app/ui/widgets/async_view.dart';
import 'package:wc_app/ui/widgets/match_card.dart';

class ResultsScreen extends StatefulWidget {
  final ResultsController controller;
  const ResultsScreen({super.key, required this.controller});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return AsyncView<List<Match>>(
          loading: c.loading,
          error: c.error,
          data: c.matches,
          onRetry: c.load,
          builder: (matches) => RefreshIndicator(
            onRefresh: c.load,
            child: ListView(children: matches.map((m) => MatchCard(m)).toList()),
          ),
        );
      },
    );
  }
}
