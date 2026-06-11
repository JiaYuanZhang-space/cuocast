import 'package:flutter/material.dart';
import 'package:wc_app/state/standings_controller.dart';
import 'package:wc_app/models/standing.dart';
import 'package:wc_app/ui/widgets/async_view.dart';

class StandingsScreen extends StatefulWidget {
  final StandingsController controller;
  const StandingsScreen({super.key, required this.controller});
  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
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
        return AsyncView<List<Standing>>(
          loading: c.loading,
          error: c.error,
          data: c.standings,
          onRetry: c.load,
          builder: (rows) => RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              children: [
                DataTable(
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('队')),
                    DataColumn(label: Text('赛'), numeric: true),
                    DataColumn(label: Text('净'), numeric: true),
                    DataColumn(label: Text('分'), numeric: true),
                  ],
                  rows: rows.map((s) => DataRow(cells: [
                    DataCell(Text('${s.rank}')),
                    DataCell(Text(s.team)),
                    DataCell(Text('${s.played}')),
                    DataCell(Text('${s.goalsDiff}')),
                    DataCell(Text('${s.points}')),
                  ])).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
