import 'package:flutter/material.dart';
import 'package:wc_app/state/fixtures_controller.dart';
import 'package:wc_app/ui/widgets/async_view.dart';
import 'package:wc_app/ui/widgets/match_card.dart';

class FixturesScreen extends StatefulWidget {
  final FixturesController controller;
  const FixturesScreen({super.key, required this.controller});
  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
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
        return AsyncView<List>(
          loading: c.loading,
          error: c.error,
          data: c.matches,
          onRetry: c.load,
          builder: (matches) => RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              children: matches.map((m) => MatchCard(m)).toList(),
            ),
          ),
        );
      },
    );
  }
}
