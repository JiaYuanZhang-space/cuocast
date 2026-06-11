import 'package:flutter/material.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/fixtures_controller.dart';
import 'package:wc_app/state/live_controller.dart';
import 'package:wc_app/state/results_controller.dart';
import 'package:wc_app/state/standings_controller.dart';
import 'package:wc_app/state/odds_controller.dart';
import 'package:wc_app/ui/fixtures_screen.dart';
import 'package:wc_app/ui/live_screen.dart';
import 'package:wc_app/ui/results_screen.dart';
import 'package:wc_app/ui/standings_screen.dart';
import 'package:wc_app/ui/odds_screen.dart';

class HomeScaffold extends StatefulWidget {
  final Repository repository;
  const HomeScaffold({super.key, required this.repository});
  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _index = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    final r = widget.repository;
    _pages = [
      FixturesScreen(controller: FixturesController(r)),
      LiveScreen(controller: LiveController(r)),
      ResultsScreen(controller: ResultsController(r)),
      StandingsScreen(controller: StandingsController(r)),
      OddsScreen(controller: OddsController(r), matchId: 101),
    ];
  }

  static const _titles = ['赛程', '实况', '结果', '积分', '赔率'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('世界杯 2026 · ${_titles[_index]}')),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today), label: '赛程'),
          NavigationDestination(icon: Icon(Icons.circle), label: '实况'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '结果'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: '积分'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: '赔率'),
        ],
      ),
    );
  }
}
