import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/config.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/ui/home_scaffold.dart';

void main() {
  runApp(const WcApp());
}

class WcApp extends StatelessWidget {
  const WcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '世界杯 2026',
      theme: ThemeData.dark(useMaterial3: true),
      home: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final repo = Repository(
            api: ApiClient(baseUrl: Config.proxyBaseUrl),
            cache: LocalCache(snap.data!),
          );
          return HomeScaffold(repository: repo);
        },
      ),
    );
  }
}
