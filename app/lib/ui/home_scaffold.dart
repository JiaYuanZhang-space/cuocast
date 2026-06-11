import 'package:flutter/material.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});
  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _index = 0;

  static const _pages = <Widget>[
    SizedBox.shrink(),
    SizedBox.shrink(),
    SizedBox.shrink(),
    SizedBox.shrink(),
    SizedBox.shrink(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
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
