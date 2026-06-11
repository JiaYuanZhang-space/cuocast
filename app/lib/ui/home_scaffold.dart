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
  late final FixturesController _fixtures;
  late final LiveController _live;
  late final ResultsController _results;
  late final StandingsController _standings;
  late final OddsController _odds;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    final r = widget.repository;
    _fixtures = FixturesController(r);
    _live = LiveController(r);
    _results = ResultsController(r);
    _standings = StandingsController(r);
    _odds = OddsController(r);
    _pages = [
      FixturesScreen(controller: _fixtures),
      LiveScreen(controller: _live),
      ResultsScreen(controller: _results),
      StandingsScreen(controller: _standings),
      OddsScreen(controller: _odds, matchId: 101),
    ];
  }

  @override
  void dispose() {
    _fixtures.dispose();
    _live.dispose(); // cancels the polling timer
    _results.dispose();
    _standings.dispose();
    _odds.dispose();
    super.dispose();
  }

  static const _titles = ['赛程', '实况', '结果', '积分', '赔率'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('球程 · ${_titles[_index]}')),
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
