import 'package:flutter/material.dart';
import 'package:wc_app/models/match.dart';
import 'package:wc_app/state/live_controller.dart';
import 'package:wc_app/ui/widgets/async_view.dart';
import 'package:wc_app/ui/widgets/match_card.dart';

class LiveScreen extends StatefulWidget {
  final LiveController controller;
  const LiveScreen({super.key, required this.controller});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.startPolling();
  }

  @override
  void dispose() {
    widget.controller.stopPolling();
    super.dispose();
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
          builder: (matches) => matches.isEmpty
              ? const Center(child: Text('暂无进行中的比赛'))
              : RefreshIndicator(
                  onRefresh: c.load,
                  child: ListView(children: matches.map((m) => MatchCard(m)).toList()),
                ),
        );
      },
    );
  }
}
