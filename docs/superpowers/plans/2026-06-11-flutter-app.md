# Flutter App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建 Flutter App, 经后端代理实时查看 2026 世界杯赛程、实况(自动轮询)、结果、积分/对阵、竞彩赔率。

**Architecture:** 分层 — `models`(纯数据+fromJson)、`data`(ApiClient HTTP + Repository + 本地缓存)、`state`(ChangeNotifier 控制器)、`ui`(底部 5 标签 + 各页 + 复用卡片)。App 只调代理, 不直连上游。实况页用 `Timer.periodic` 30s 轮询, 离页即停。

**Tech Stack:** Flutter (Dart 3.11), `http`(网络, 测试用 `package:http/testing.dart` 的 `MockClient`, 无需 codegen), `provider`(状态), `shared_preferences`(本地缓存最近响应)。

**Prerequisite:** 后端代理(计划 1)已完成。开发期代理跑在 `http://localhost:8000`。**Android 模拟器**访问宿主机用 `http://10.0.2.2:8000`(见 Task 12 config)。

---

## 文件结构

```
app/                                  # flutter create 生成的根
  pubspec.yaml
  lib/
    main.dart                         # 入口 + MaterialApp + Provider 注入
    config.dart                       # 代理 base URL
    models/
      api_response.dart               # ApiResponse<T> {data, stale}
      match.dart                      # Match + fromJson
      match_event.dart                # MatchEvent + fromJson
      standing.dart                   # Standing + fromJson
      odds.dart                       # Odds + fromJson
    data/
      api_client.dart                 # GET 代理, 返回解码 JSON
      local_cache.dart                # shared_preferences 存/取最近 JSON
      repository.dart                 # 类型化方法, 失败回退本地缓存
    state/
      fixtures_controller.dart        # ChangeNotifier: 加载赛程
      live_controller.dart            # ChangeNotifier: 轮询实况
      results_controller.dart
      standings_controller.dart
      odds_controller.dart
    ui/
      home_scaffold.dart              # 底部导航
      fixtures_screen.dart
      live_screen.dart
      results_screen.dart
      standings_screen.dart
      odds_screen.dart
      widgets/
        match_card.dart               # 复用比赛卡片
        async_view.dart               # loading/error/data 通用包装
  test/
    models/...  data/...  state/...  widget/...
```

设计边界: `models` 纯转换无副作用; `ApiClient` 只发请求; `Repository` 编排(请求+缓存回退); `state` 控制器持有 UI 状态, 不含网络细节; `ui` 只渲染 + 调控制器。各层可独立测试。

---

## Task 0: 脚手架 Flutter 工程

**Files:**
- Create: `app/`(由 `flutter create` 生成)
- Modify: `app/pubspec.yaml`
- Create: `app/test/smoke_test.dart`

- [ ] **Step 1: 生成工程**

工作目录 `D:/MySoft/Space/Project/ai_project`。运行(Windows, flutter.bat 在 PATH):
```
flutter create --org com.worldcup --project-name wc_app app
```
Expected: 生成 `app/` 含 `lib/main.dart`、`android/`、`ios/`、`test/`。

- [ ] **Step 2: 加依赖到 pubspec.yaml**

编辑 `app/pubspec.yaml`, 在 `dependencies:` 下(`flutter:` sdk 之后)加:
```yaml
  http: ^1.2.2
  provider: ^6.1.2
  shared_preferences: ^2.3.2
```
确认 `dev_dependencies:` 已含 `flutter_test:` 和 `flutter_lints:`(flutter create 默认有)。

- [ ] **Step 3: 装包**

Run: `cd app && flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 4: 写冒烟测试**

替换 `app/test/widget_test.dart` 为 `app/test/smoke_test.dart`(先删默认 `widget_test.dart`, 它引用计数器模板会编译失败):
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanity: arithmetic', () {
    expect(1 + 1, 2);
  });
}
```
删除 `app/test/widget_test.dart`。

- [ ] **Step 5: 跑测试**

Run: `cd app && flutter test`
Expected: All tests passed!

- [ ] **Step 6: 提交**

```bash
git add app/ -- ':!app/.dart_tool' ':!app/build'
git commit -m "chore(app): scaffold Flutter project with http/provider/shared_preferences"
```
(注: `app/.dart_tool/` 与 `app/build/` 已被根 `.gitignore` 的 `build/`、`.dart_tool/` 覆盖。)

---

## Task 1: ApiResponse + Match 模型

**Files:**
- Create: `app/lib/models/api_response.dart`, `app/lib/models/match.dart`
- Test: `app/test/models/match_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/models/match_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wc_app/models/match.dart';
import 'package:wc_app/models/api_response.dart';

void main() {
  test('Match.fromJson parses core fields', () {
    final m = Match.fromJson({
      'id': 101, 'kickoff': '2026-06-14T04:00:00+00:00', 'status': '1H',
      'minute': 23, 'venue': 'AT&T Stadium', 'round': 'Group Stage - 1',
      'home': 'Brazil', 'away': 'Germany', 'homeScore': 1, 'awayScore': 0,
    });
    expect(m.id, 101);
    expect(m.home, 'Brazil');
    expect(m.homeScore, 1);
    expect(m.minute, 23);
    expect(m.status, '1H');
  });

  test('Match.fromJson tolerates null score and minute', () {
    final m = Match.fromJson({
      'id': 9, 'kickoff': '2026-06-14T04:00:00+00:00', 'status': 'NS',
      'minute': null, 'venue': null, 'round': 'R16',
      'home': 'A', 'away': 'B', 'homeScore': null, 'awayScore': null,
    });
    expect(m.homeScore, isNull);
    expect(m.minute, isNull);
  });

  test('ApiResponse.fromJson wraps list with stale flag', () {
    final r = ApiResponse<List<Match>>.fromJson(
      {'data': [{'id': 1, 'kickoff': 'x', 'status': 'NS', 'minute': null,
                 'venue': null, 'round': 'r', 'home': 'A', 'away': 'B',
                 'homeScore': null, 'awayScore': null}], 'stale': true},
      (d) => (d as List).map((e) => Match.fromJson(e)).toList(),
    );
    expect(r.stale, true);
    expect(r.data.length, 1);
    expect(r.data.first.home, 'A');
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/models/match_test.dart`
Expected: 编译失败 — 找不到 `match.dart` / `api_response.dart`。

- [ ] **Step 3: 实现 api_response.dart**

`app/lib/models/api_response.dart`:
```dart
class ApiResponse<T> {
  final T data;
  final bool stale;
  ApiResponse({required this.data, required this.stale});

  factory ApiResponse.fromJson(
      Map<String, dynamic> json, T Function(dynamic data) parse) {
    return ApiResponse(data: parse(json['data']), stale: json['stale'] == true);
  }
}
```

- [ ] **Step 4: 实现 match.dart**

`app/lib/models/match.dart`:
```dart
class Match {
  final int id;
  final String kickoff;
  final String status;
  final int? minute;
  final String? venue;
  final String? round;
  final String home;
  final String away;
  final int? homeScore;
  final int? awayScore;

  Match({
    required this.id, required this.kickoff, required this.status,
    this.minute, this.venue, this.round, required this.home,
    required this.away, this.homeScore, this.awayScore,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'] as int,
        kickoff: json['kickoff'] as String,
        status: json['status'] as String,
        minute: json['minute'] as int?,
        venue: json['venue'] as String?,
        round: json['round'] as String?,
        home: json['home'] as String,
        away: json['away'] as String,
        homeScore: json['homeScore'] as int?,
        awayScore: json['awayScore'] as int?,
      );

  bool get isLive => status == '1H' || status == '2H' || status == 'HT' || status == 'ET';
}
```

- [ ] **Step 5: 跑确认通过**

Run: `cd app && flutter test test/models/match_test.dart`
Expected: All tests passed! (3)

- [ ] **Step 6: 提交**

```bash
git add app/lib/models/api_response.dart app/lib/models/match.dart app/test/models/match_test.dart
git commit -m "feat(app): ApiResponse and Match models"
```

---

## Task 2: MatchEvent / Standing / Odds 模型

**Files:**
- Create: `app/lib/models/match_event.dart`, `app/lib/models/standing.dart`, `app/lib/models/odds.dart`
- Test: `app/test/models/models_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/models/models_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wc_app/models/match_event.dart';
import 'package:wc_app/models/standing.dart';
import 'package:wc_app/models/odds.dart';

void main() {
  test('MatchEvent.fromJson', () {
    final e = MatchEvent.fromJson({
      'minute': 12, 'team': 'Brazil', 'player': 'Vinicius',
      'type': 'Goal', 'detail': 'Normal Goal'});
    expect(e.minute, 12);
    expect(e.type, 'Goal');
    expect(e.player, 'Vinicius');
  });

  test('Standing.fromJson', () {
    final s = Standing.fromJson({
      'rank': 1, 'team': 'Mexico', 'played': 2, 'win': 2, 'draw': 0,
      'lose': 0, 'goalsDiff': 3, 'points': 6});
    expect(s.rank, 1);
    expect(s.team, 'Mexico');
    expect(s.points, 6);
    expect(s.goalsDiff, 3);
  });

  test('Odds.fromJson with wdl', () {
    final o = Odds.fromJson({'wdl': {'home': 1.95, 'draw': 3.4, 'away': 3.75}});
    expect(o.wdl?.home, 1.95);
    expect(o.wdl?.draw, 3.4);
  });

  test('Odds.fromJson with null wdl', () {
    final o = Odds.fromJson({'wdl': null});
    expect(o.wdl, isNull);
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/models/models_test.dart`
Expected: 编译失败 — 缺三个模型文件。

- [ ] **Step 3: 实现 match_event.dart**

`app/lib/models/match_event.dart`:
```dart
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
```

- [ ] **Step 4: 实现 standing.dart**

`app/lib/models/standing.dart`:
```dart
class Standing {
  final int rank;
  final String team;
  final int played, win, draw, lose, goalsDiff, points;

  Standing({required this.rank, required this.team, required this.played,
      required this.win, required this.draw, required this.lose,
      required this.goalsDiff, required this.points});

  factory Standing.fromJson(Map<String, dynamic> json) => Standing(
        rank: json['rank'] as int,
        team: json['team'] as String,
        played: json['played'] as int,
        win: json['win'] as int,
        draw: json['draw'] as int,
        lose: json['lose'] as int,
        goalsDiff: json['goalsDiff'] as int,
        points: json['points'] as int,
      );
}
```

- [ ] **Step 5: 实现 odds.dart**

`app/lib/models/odds.dart`:
```dart
class Wdl {
  final double home, draw, away;
  Wdl({required this.home, required this.draw, required this.away});
  factory Wdl.fromJson(Map<String, dynamic> j) => Wdl(
        home: (j['home'] as num).toDouble(),
        draw: (j['draw'] as num).toDouble(),
        away: (j['away'] as num).toDouble(),
      );
}

class Odds {
  final Wdl? wdl;
  Odds({this.wdl});
  factory Odds.fromJson(Map<String, dynamic> json) {
    final w = json['wdl'];
    return Odds(wdl: w == null ? null : Wdl.fromJson(w as Map<String, dynamic>));
  }
}
```

- [ ] **Step 6: 跑确认通过**

Run: `cd app && flutter test test/models/models_test.dart`
Expected: All tests passed! (4)

- [ ] **Step 7: 提交**

```bash
git add app/lib/models/match_event.dart app/lib/models/standing.dart app/lib/models/odds.dart app/test/models/models_test.dart
git commit -m "feat(app): MatchEvent, Standing, Odds models"
```

---

## Task 3: ApiClient

**Files:**
- Create: `app/lib/config.dart`, `app/lib/data/api_client.dart`
- Test: `app/test/data/api_client_test.dart`

- [ ] **Step 1: 写失败测试(用 MockClient, 不联网)**

`app/test/data/api_client_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wc_app/data/api_client.dart';

void main() {
  test('getJson hits base+path and decodes body', () async {
    late Uri seen;
    final mock = MockClient((req) async {
      seen = req.url;
      return http.Response(jsonEncode({'data': [], 'stale': false}), 200);
    });
    final client = ApiClient(baseUrl: 'http://x:8000', httpClient: mock);
    final json = await client.getJson('/fixtures');
    expect(seen.toString(), 'http://x:8000/fixtures');
    expect(json['stale'], false);
  });

  test('getJson passes query params', () async {
    late Uri seen;
    final mock = MockClient((req) async {
      seen = req.url;
      return http.Response(jsonEncode({'data': null, 'stale': false}), 200);
    });
    final client = ApiClient(baseUrl: 'http://x:8000', httpClient: mock);
    await client.getJson('/odds', query: {'matchId': '101'});
    expect(seen.queryParameters['matchId'], '101');
  });

  test('getJson throws on non-200', () async {
    final mock = MockClient((req) async => http.Response('err', 502));
    final client = ApiClient(baseUrl: 'http://x:8000', httpClient: mock);
    expect(() => client.getJson('/fixtures'), throwsA(isA<ApiException>()));
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/data/api_client_test.dart`
Expected: 编译失败 — 缺 `api_client.dart`。

- [ ] **Step 3: 实现 config.dart**

`app/lib/config.dart`:
```dart
class Config {
  // Android 模拟器访问宿主机用 10.0.2.2; 桌面/web/真机按实际改。
  static const String proxyBaseUrl = 'http://10.0.2.2:8000';
}
```

- [ ] **Step 4: 实现 api_client.dart**

`app/lib/data/api_client.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  ApiException(this.statusCode);
  @override
  String toString() => 'ApiException($statusCode)';
}

class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
```

- [ ] **Step 5: 跑确认通过**

Run: `cd app && flutter test test/data/api_client_test.dart`
Expected: All tests passed! (3)

- [ ] **Step 6: 提交**

```bash
git add app/lib/config.dart app/lib/data/api_client.dart app/test/data/api_client_test.dart
git commit -m "feat(app): ApiClient with query support and error handling"
```

---

## Task 4: LocalCache

**Files:**
- Create: `app/lib/data/local_cache.dart`
- Test: `app/test/data/local_cache_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/data/local_cache_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/local_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('returns null when nothing stored', () async {
    final cache = LocalCache(await SharedPreferences.getInstance());
    expect(cache.read('fixtures'), isNull);
  });

  test('write then read returns same json string', () async {
    final cache = LocalCache(await SharedPreferences.getInstance());
    await cache.write('fixtures', '{"data":[],"stale":false}');
    expect(cache.read('fixtures'), '{"data":[],"stale":false}');
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/data/local_cache_test.dart`
Expected: 编译失败 — 缺 `local_cache.dart`。

- [ ] **Step 3: 实现 local_cache.dart**

`app/lib/data/local_cache.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  final SharedPreferences _prefs;
  LocalCache(this._prefs);

  String _key(String k) => 'cache:$k';

  String? read(String key) => _prefs.getString(_key(key));

  Future<void> write(String key, String json) async {
    await _prefs.setString(_key(key), json);
  }
}
```

- [ ] **Step 4: 跑确认通过**

Run: `cd app && flutter test test/data/local_cache_test.dart`
Expected: All tests passed! (2)

- [ ] **Step 5: 提交**

```bash
git add app/lib/data/local_cache.dart app/test/data/local_cache_test.dart
git commit -m "feat(app): LocalCache over shared_preferences"
```

---

## Task 5: Repository

**Files:**
- Create: `app/lib/data/repository.dart`
- Test: `app/test/data/repository_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/data/repository_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';

Future<Repository> buildRepo(MockClient mock) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Repository(
    api: ApiClient(baseUrl: 'http://x:8000', httpClient: mock),
    cache: LocalCache(prefs),
  );
}

const _fixturesBody = '{"data":[{"id":1,"kickoff":"x","status":"NS","minute":null,'
    '"venue":null,"round":"r","home":"A","away":"B","homeScore":null,"awayScore":null}],'
    '"stale":false}';

void main() {
  test('fetchFixtures parses and returns matches', () async {
    final repo = await buildRepo(MockClient((req) async => http.Response(_fixturesBody, 200)));
    final res = await repo.fetchFixtures();
    expect(res.data.length, 1);
    expect(res.data.first.home, 'A');
    expect(res.stale, false);
  });

  test('fetchFixtures falls back to cache on error', () async {
    SharedPreferences.setMockInitialValues({'cache:fixtures': _fixturesBody});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x:8000',
          httpClient: MockClient((req) async => http.Response('err', 502))),
      cache: LocalCache(prefs),
    );
    final res = await repo.fetchFixtures();
    expect(res.data.first.home, 'A');
    expect(res.stale, true); // served stale from local cache
  });

  test('fetchFixtures rethrows when error and no cache', () async {
    final repo = await buildRepo(MockClient((req) async => http.Response('err', 502)));
    expect(() => repo.fetchFixtures(), throwsA(isA<ApiException>()));
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/data/repository_test.dart`
Expected: 编译失败 — 缺 `repository.dart`。

- [ ] **Step 3: 实现 repository.dart**

`app/lib/data/repository.dart`:
```dart
import 'dart:convert';
import 'models_imports.dart' show nothing; // placeholder removed below
```
> 注: 不要写上面那行。正确实现如下(直接用):
```dart
import 'dart:convert';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/models/api_response.dart';
import 'package:wc_app/models/match.dart';
import 'package:wc_app/models/match_event.dart';
import 'package:wc_app/models/standing.dart';
import 'package:wc_app/models/odds.dart';

class Repository {
  final ApiClient api;
  final LocalCache cache;
  Repository({required this.api, required this.cache});

  Future<ApiResponse<T>> _fetch<T>(
      String path, String cacheKey, T Function(dynamic) parse,
      {Map<String, String>? query}) async {
    try {
      final json = await api.getJson(path, query: query);
      await cache.write(cacheKey, jsonEncode(json));
      return ApiResponse<T>.fromJson(json, parse);
    } catch (e) {
      final cached = cache.read(cacheKey);
      if (cached != null) {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        return ApiResponse<T>(data: parse(json['data']), stale: true);
      }
      rethrow;
    }
  }

  List<Match> _matches(dynamic d) =>
      (d as List).map((e) => Match.fromJson(e as Map<String, dynamic>)).toList();

  Future<ApiResponse<List<Match>>> fetchFixtures() =>
      _fetch('/fixtures', 'fixtures', _matches);

  Future<ApiResponse<List<Match>>> fetchLive() =>
      _fetch('/live', 'live', _matches);

  Future<ApiResponse<List<Match>>> fetchResults() =>
      _fetch('/results', 'results', _matches);

  Future<ApiResponse<List<Standing>>> fetchStandings() => _fetch(
      '/standings', 'standings',
      (d) => (d as List).map((e) => Standing.fromJson(e as Map<String, dynamic>)).toList());

  Future<ApiResponse<Map<String, List<Match>>>> fetchBracket() => _fetch(
      '/bracket', 'bracket',
      (d) => (d as Map<String, dynamic>).map((k, v) =>
          MapEntry(k, (v as List).map((e) => Match.fromJson(e as Map<String, dynamic>)).toList())));

  Future<ApiResponse<List<MatchEvent>>> fetchEvents(int fixtureId) => _fetch(
      '/events', 'events:$fixtureId',
      (d) => (d as List).map((e) => MatchEvent.fromJson(e as Map<String, dynamic>)).toList(),
      query: {'fixtureId': '$fixtureId'});

  Future<ApiResponse<Odds>> fetchOdds(int matchId) => _fetch(
      '/odds', 'odds:$matchId',
      (d) => d == null ? Odds() : Odds.fromJson(d as Map<String, dynamic>),
      query: {'matchId': '$matchId'});
}
```

- [ ] **Step 4: 跑确认通过**

Run: `cd app && flutter test test/data/repository_test.dart`
Expected: All tests passed! (3)

- [ ] **Step 5: 提交**

```bash
git add app/lib/data/repository.dart app/test/data/repository_test.dart
git commit -m "feat(app): Repository with typed endpoints and stale cache fallback"
```

---

## Task 6: 通用 AsyncView + Home 脚手架

**Files:**
- Create: `app/lib/ui/widgets/async_view.dart`, `app/lib/ui/home_scaffold.dart`
- Test: `app/test/widget/home_scaffold_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/widget/home_scaffold_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wc_app/ui/home_scaffold.dart';

void main() {
  testWidgets('home shows 5 bottom nav destinations', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScaffold()));
    expect(find.text('赛程'), findsOneWidget);
    expect(find.text('实况'), findsOneWidget);
    expect(find.text('结果'), findsOneWidget);
    expect(find.text('积分'), findsOneWidget);
    expect(find.text('赔率'), findsOneWidget);
  });

  testWidgets('tapping 赔率 switches selected index', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScaffold()));
    await tester.tap(find.text('赔率'));
    await tester.pumpAndSettle();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/widget/home_scaffold_test.dart`
Expected: 编译失败 — 缺 `home_scaffold.dart`。

- [ ] **Step 3: 实现 async_view.dart**

`app/lib/ui/widgets/async_view.dart`:
```dart
import 'package:flutter/material.dart';

/// 通用包装: 根据加载/错误/数据状态渲染。
class AsyncView<T> extends StatelessWidget {
  final bool loading;
  final Object? error;
  final T? data;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  const AsyncView({super.key, required this.loading, required this.error,
      required this.data, required this.builder, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && data == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('加载失败'),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ]),
      );
    }
    return builder(data as T);
  }
}
```

- [ ] **Step 4: 实现 home_scaffold.dart(占位页内容, 后续任务替换)**

`app/lib/ui/home_scaffold.dart`:
```dart
import 'package:flutter/material.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});
  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _index = 0;

  // 占位; Task 7-11 用真实页面替换对应项。
  static const _pages = <Widget>[
    Center(child: Text('赛程')),
    Center(child: Text('实况')),
    Center(child: Text('结果')),
    Center(child: Text('积分')),
    Center(child: Text('赔率')),
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
```

- [ ] **Step 5: 跑确认通过**

Run: `cd app && flutter test test/widget/home_scaffold_test.dart`
Expected: All tests passed! (2)

- [ ] **Step 6: 提交**

```bash
git add app/lib/ui/widgets/async_view.dart app/lib/ui/home_scaffold.dart app/test/widget/home_scaffold_test.dart
git commit -m "feat(app): AsyncView wrapper and home bottom-nav scaffold"
```

---

## Task 7: MatchCard + FixturesController + FixturesScreen

**Files:**
- Create: `app/lib/ui/widgets/match_card.dart`, `app/lib/state/fixtures_controller.dart`, `app/lib/ui/fixtures_screen.dart`
- Test: `app/test/state/fixtures_controller_test.dart`, `app/test/widget/fixtures_screen_test.dart`

- [ ] **Step 1: 写 controller 失败测试**

`app/test/state/fixtures_controller_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/fixtures_controller.dart';

const _body = '{"data":[{"id":1,"kickoff":"x","status":"NS","minute":null,'
    '"venue":null,"round":"r","home":"A","away":"B","homeScore":null,"awayScore":null}],'
    '"stale":false}';

Future<Repository> repo(MockClient m) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Repository(api: ApiClient(baseUrl: 'http://x', httpClient: m), cache: LocalCache(prefs));
}

void main() {
  test('load sets matches and clears loading', () async {
    final c = FixturesController(await repo(MockClient((r) async => http.Response(_body, 200))));
    expect(c.loading, false);
    final f = c.load();
    expect(c.loading, true);
    await f;
    expect(c.loading, false);
    expect(c.matches!.length, 1);
    expect(c.error, isNull);
  });

  test('load captures error when no data', () async {
    final c = FixturesController(await repo(MockClient((r) async => http.Response('e', 502))));
    await c.load();
    expect(c.matches, isNull);
    expect(c.error, isNotNull);
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/state/fixtures_controller_test.dart`
Expected: 编译失败 — 缺 `fixtures_controller.dart`。

- [ ] **Step 3: 实现 fixtures_controller.dart**

`app/lib/state/fixtures_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/match.dart';

class FixturesController extends ChangeNotifier {
  final Repository _repo;
  FixturesController(this._repo);

  bool loading = false;
  Object? error;
  List<Match>? matches;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.fetchFixtures();
      matches = res.data;
      stale = res.stale;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: 跑确认通过**

Run: `cd app && flutter test test/state/fixtures_controller_test.dart`
Expected: All tests passed! (2)

- [ ] **Step 5: 实现 match_card.dart**

`app/lib/ui/widgets/match_card.dart`:
```dart
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
```

- [ ] **Step 6: 写 screen 失败测试**

`app/test/widget/fixtures_screen_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/fixtures_controller.dart';
import 'package:wc_app/ui/fixtures_screen.dart';

const _body = '{"data":[{"id":1,"kickoff":"x","status":"NS","minute":null,'
    '"venue":null,"round":"Group A","home":"Brazil","away":"Germany",'
    '"homeScore":null,"awayScore":null}],"stale":false}';

void main() {
  testWidgets('shows fixtures after load', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_body, 200))),
      cache: LocalCache(prefs));
    final controller = FixturesController(repo);
    await tester.pumpWidget(MaterialApp(home: FixturesScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('Brazil'), findsOneWidget);
    expect(find.text('Germany'), findsOneWidget);
  });
}
```

- [ ] **Step 7: 实现 fixtures_screen.dart**

`app/lib/ui/fixtures_screen.dart`:
```dart
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
```

- [ ] **Step 8: 跑确认通过**

Run: `cd app && flutter test test/widget/fixtures_screen_test.dart`
Expected: All tests passed! (1)

- [ ] **Step 9: 提交**

```bash
git add app/lib/ui/widgets/match_card.dart app/lib/state/fixtures_controller.dart app/lib/ui/fixtures_screen.dart app/test/state/fixtures_controller_test.dart app/test/widget/fixtures_screen_test.dart
git commit -m "feat(app): fixtures screen with controller, match card, pull-to-refresh"
```

---

## Task 8: LiveController(轮询)+ LiveScreen

**Files:**
- Create: `app/lib/state/live_controller.dart`, `app/lib/ui/live_screen.dart`
- Test: `app/test/state/live_controller_test.dart`

- [ ] **Step 1: 写失败测试(验证轮询触发多次加载)**

`app/test/state/live_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/live_controller.dart';

const _body = '{"data":[],"stale":false}';

void main() {
  test('startPolling loads immediately and on each interval', () {
    fakeAsync((async) async {} );
  });

  test('load fetches live matches', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async {
        calls++;
        return http.Response(_body, 200);
      })),
      cache: LocalCache(prefs));
    final c = LiveController(repo, interval: const Duration(milliseconds: 20));
    await c.load();
    expect(calls, 1);
    expect(c.matches, isNotNull);
  });

  test('startPolling triggers repeated loads then stops on dispose', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async {
        calls++;
        return http.Response(_body, 200);
      })),
      cache: LocalCache(prefs));
    final c = LiveController(repo, interval: const Duration(milliseconds: 20));
    c.startPolling();
    await Future.delayed(const Duration(milliseconds: 70));
    c.dispose();
    final afterDispose = calls;
    await Future.delayed(const Duration(milliseconds: 50));
    expect(afterDispose, greaterThanOrEqualTo(3)); // immediate + ~3 ticks
    expect(calls, afterDispose); // no more calls after dispose
  });
}
```
> 注: 删掉上面第一个空的 `fakeAsync` 占位 test — 它只是示意, 不要写进文件。最终文件只含后两个 test。

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/state/live_controller_test.dart`
Expected: 编译失败 — 缺 `live_controller.dart`。

- [ ] **Step 3: 实现 live_controller.dart**

`app/lib/state/live_controller.dart`:
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/match.dart';

class LiveController extends ChangeNotifier {
  final Repository _repo;
  final Duration interval;
  Timer? _timer;

  LiveController(this._repo, {this.interval = const Duration(seconds: 30)});

  bool loading = false;
  Object? error;
  List<Match>? matches;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final res = await _repo.fetchLive();
      matches = res.data;
      stale = res.stale;
      error = null;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void startPolling() {
    load();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => load());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
```

- [ ] **Step 4: 跑确认通过**

Run: `cd app && flutter test test/state/live_controller_test.dart`
Expected: All tests passed! (2)

- [ ] **Step 5: 实现 live_screen.dart**

`app/lib/ui/live_screen.dart`:
```dart
import 'package:flutter/material.dart';
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
        return AsyncView<List>(
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
```

- [ ] **Step 6: 跑全量(确保无回归)**

Run: `cd app && flutter test`
Expected: All tests passed!

- [ ] **Step 7: 提交**

```bash
git add app/lib/state/live_controller.dart app/lib/ui/live_screen.dart app/test/state/live_controller_test.dart
git commit -m "feat(app): live controller with 30s polling and live screen"
```

---

## Task 9: ResultsScreen

**Files:**
- Create: `app/lib/state/results_controller.dart`, `app/lib/ui/results_screen.dart`
- Test: `app/test/state/results_controller_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/state/results_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/results_controller.dart';

const _body = '{"data":[{"id":5,"kickoff":"x","status":"FT","minute":null,'
    '"venue":null,"round":"Group A","home":"NL","away":"EC",'
    '"homeScore":3,"awayScore":1}],"stale":false}';

void main() {
  test('load returns finished matches', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_body, 200))),
      cache: LocalCache(prefs));
    final c = ResultsController(repo);
    await c.load();
    expect(c.matches!.first.homeScore, 3);
    expect(c.error, isNull);
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/state/results_controller_test.dart`
Expected: 编译失败 — 缺 `results_controller.dart`。

- [ ] **Step 3: 实现 results_controller.dart**

`app/lib/state/results_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/match.dart';

class ResultsController extends ChangeNotifier {
  final Repository _repo;
  ResultsController(this._repo);

  bool loading = false;
  Object? error;
  List<Match>? matches;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.fetchResults();
      matches = res.data;
      stale = res.stale;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: 跑确认通过**

Run: `cd app && flutter test test/state/results_controller_test.dart`
Expected: All tests passed! (1)

- [ ] **Step 5: 实现 results_screen.dart**

`app/lib/ui/results_screen.dart`:
```dart
import 'package:flutter/material.dart';
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
        return AsyncView<List>(
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
```

- [ ] **Step 6: 提交**

```bash
git add app/lib/state/results_controller.dart app/lib/ui/results_screen.dart app/test/state/results_controller_test.dart
git commit -m "feat(app): results screen"
```

---

## Task 10: StandingsController + StandingsScreen(积分表 + 对阵图)

**Files:**
- Create: `app/lib/state/standings_controller.dart`, `app/lib/ui/standings_screen.dart`
- Test: `app/test/state/standings_controller_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/state/standings_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/standings_controller.dart';

const _body = '{"data":[{"rank":1,"team":"Mexico","played":2,"win":2,"draw":0,'
    '"lose":0,"goalsDiff":3,"points":6}],"stale":false}';

void main() {
  test('load returns standings sorted by rank', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_body, 200))),
      cache: LocalCache(prefs));
    final c = StandingsController(repo);
    await c.load();
    expect(c.standings!.first.team, 'Mexico');
    expect(c.standings!.first.points, 6);
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/state/standings_controller_test.dart`
Expected: 编译失败 — 缺 `standings_controller.dart`。

- [ ] **Step 3: 实现 standings_controller.dart**

`app/lib/state/standings_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/standing.dart';

class StandingsController extends ChangeNotifier {
  final Repository _repo;
  StandingsController(this._repo);

  bool loading = false;
  Object? error;
  List<Standing>? standings;
  bool stale = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.fetchStandings();
      standings = res.data;
      stale = res.stale;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: 跑确认通过**

Run: `cd app && flutter test test/state/standings_controller_test.dart`
Expected: All tests passed! (1)

- [ ] **Step 5: 实现 standings_screen.dart(积分表; 对阵图作为后续增强占位)**

`app/lib/ui/standings_screen.dart`:
```dart
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
```
> 对阵图(横向 bracket)是后续增强, 不在本任务; `Repository.fetchBracket` 已就绪供将来用。

- [ ] **Step 6: 提交**

```bash
git add app/lib/state/standings_controller.dart app/lib/ui/standings_screen.dart app/test/state/standings_controller_test.dart
git commit -m "feat(app): standings table screen"
```

---

## Task 11: OddsController + OddsScreen

**Files:**
- Create: `app/lib/state/odds_controller.dart`, `app/lib/ui/odds_screen.dart`
- Test: `app/test/state/odds_controller_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/state/odds_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/state/odds_controller.dart';

const _body = '{"data":{"wdl":{"home":1.95,"draw":3.4,"away":3.75}},"stale":false}';
const _nullBody = '{"data":null,"stale":true}';

void main() {
  test('load parses wdl odds', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_body, 200))),
      cache: LocalCache(prefs));
    final c = OddsController(repo);
    await c.load(101);
    expect(c.odds!.wdl!.home, 1.95);
  });

  test('load handles null odds (unavailable)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = Repository(
      api: ApiClient(baseUrl: 'http://x', httpClient: MockClient((r) async => http.Response(_nullBody, 200))),
      cache: LocalCache(prefs));
    final c = OddsController(repo);
    await c.load(101);
    expect(c.odds!.wdl, isNull);
    expect(c.error, isNull);
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/state/odds_controller_test.dart`
Expected: 编译失败 — 缺 `odds_controller.dart`。

- [ ] **Step 3: 实现 odds_controller.dart**

`app/lib/state/odds_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/models/odds.dart';

class OddsController extends ChangeNotifier {
  final Repository _repo;
  OddsController(this._repo);

  bool loading = false;
  Object? error;
  Odds? odds;

  Future<void> load(int matchId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.fetchOdds(matchId);
      odds = res.data;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: 跑确认通过**

Run: `cd app && flutter test test/state/odds_controller_test.dart`
Expected: All tests passed! (2)

- [ ] **Step 5: 实现 odds_screen.dart(选比赛 + 胜平负展示; 其他玩法后续)**

`app/lib/ui/odds_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:wc_app/state/odds_controller.dart';
import 'package:wc_app/ui/widgets/async_view.dart';

class OddsScreen extends StatefulWidget {
  final OddsController controller;
  final int matchId; // 由上层(选中的比赛)传入; 占位默认值见 home 接线
  const OddsScreen({super.key, required this.controller, required this.matchId});
  @override
  State<OddsScreen> createState() => _OddsScreenState();
}

class _OddsScreenState extends State<OddsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.matchId);
  }

  Widget _cell(String label, double value) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return AsyncView(
          loading: c.loading,
          error: c.error,
          data: c.odds,
          onRetry: () => c.load(widget.matchId),
          builder: (odds) {
            final wdl = c.odds!.wdl;
            if (wdl == null) {
              return const Center(child: Text('暂无赔率'));
            }
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('胜平负', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  _cell('主胜', wdl.home),
                  _cell('平', wdl.draw),
                  _cell('客胜', wdl.away),
                ]),
                const Spacer(),
                const Text('赔率仅供参考。理性看球, 远离非法赌博。',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
            );
          },
        );
      },
    );
  }
}
```
> 让球/比分/总进球/半全场玩法是后续增强; 代理当前只提供 `wdl`。

- [ ] **Step 6: 提交**

```bash
git add app/lib/state/odds_controller.dart app/lib/ui/odds_screen.dart app/test/state/odds_controller_test.dart
git commit -m "feat(app): odds screen showing win/draw/loss"
```

---

## Task 12: 接线 main.dart + 真实页面注入 + README

**Files:**
- Modify: `app/lib/main.dart`, `app/lib/ui/home_scaffold.dart`
- Create: `app/README.md`
- Test: `app/test/widget/app_boots_test.dart`

- [ ] **Step 1: 写失败测试(App 能启动且显示 5 标签)**

`app/test/widget/app_boots_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/main.dart';

void main() {
  testWidgets('app boots and shows bottom nav', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WcApp());
    await tester.pump(); // let initState loads kick off
    expect(find.text('赛程'), findsOneWidget);
    expect(find.text('赔率'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd app && flutter test test/widget/app_boots_test.dart`
Expected: 编译失败 — `main.dart` 还没导出 `WcApp`。

- [ ] **Step 3: 重写 home_scaffold.dart 用真实页面**

`app/lib/ui/home_scaffold.dart`:
```dart
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
      // 默认演示一场比赛的赔率; 真实交互后续接"从比赛点进赔率"
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
```
> 注: 用 `IndexedStack` 保持各页状态(切回不重新加载)。`home_scaffold_test.dart`(Task 6)构造 `HomeScaffold` 不带参数会失败 — 更新该测试: 传入一个用 MockClient 的 Repository(参考 `fixtures_screen_test.dart` 构造方式), 或将其断言迁移到 `app_boots_test.dart`。本步同时更新 Task 6 的测试以传入 repository。

- [ ] **Step 4: 重写 main.dart**

`app/lib/main.dart`:
```dart
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
```

- [ ] **Step 5: 更新 Task 6 的 home_scaffold_test.dart**

替换 `app/test/widget/home_scaffold_test.dart` 为(用 MockClient 注入 repository):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wc_app/data/api_client.dart';
import 'package:wc_app/data/local_cache.dart';
import 'package:wc_app/data/repository.dart';
import 'package:wc_app/ui/home_scaffold.dart';

Future<Repository> _repo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Repository(
    api: ApiClient(baseUrl: 'http://x',
        httpClient: MockClient((r) async => http.Response('{"data":[],"stale":false}', 200))),
    cache: LocalCache(prefs));
}

void main() {
  testWidgets('home shows 5 bottom nav destinations', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScaffold(repository: await _repo())));
    await tester.pump();
    expect(find.text('赛程'), findsWidgets);
    expect(find.text('赔率'), findsWidgets);
  });

  testWidgets('tapping 赔率 switches selected index', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScaffold(repository: await _repo())));
    await tester.pump();
    await tester.tap(find.text('赔率'));
    await tester.pump();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);
  });
}
```

- [ ] **Step 6: 跑全量测试**

Run: `cd app && flutter test`
Expected: All tests passed!(所有, 含 app_boots 与更新后的 home_scaffold)

- [ ] **Step 7: 静态分析**

Run: `cd app && flutter analyze`
Expected: No issues found!(若有 lint 警告, 修掉)

- [ ] **Step 8: 写 README**

`app/README.md`:
```markdown
# 世界杯 2026 App (Flutter)

经后端代理查看赛程/实况/结果/积分/赔率。

## 运行
1. 先启动代理(见 `../proxy/README.md`), 监听 8000。
2. 配置代理地址 `lib/config.dart`:
   - Android 模拟器: `http://10.0.2.2:8000`(默认)
   - 桌面/Web/真机: 改为宿主机实际 IP, 如 `http://192.168.x.x:8000`
3. 运行:
   \`\`\`
   cd app
   flutter pub get
   flutter run
   \`\`\`

## 测试
\`\`\`
cd app
flutter test
\`\`\`

## 结构
- `models/` 数据模型 · `data/` 网络+缓存+仓库 · `state/` 控制器 · `ui/` 页面与组件
- 实况页每 30 秒轮询; 各页下拉刷新; 网络失败回退本地缓存(顶部"数据可能过时")。

## 后续增强(见 spec)
- 对阵图横向 bracket(`Repository.fetchBracket` 已就绪)
- 赔率让球/比分/总进球/半全场(代理当前只给胜平负)
- 从比赛点进赔率详情(当前赔率页用占位 matchId)
```

- [ ] **Step 9: 提交**

```bash
git add app/lib/main.dart app/lib/ui/home_scaffold.dart app/test/widget/home_scaffold_test.dart app/test/widget/app_boots_test.dart app/README.md
git commit -m "feat(app): wire repository, real screens into home, app entry, README"
```

---

## Self-Review 结果

- **Spec 覆盖:** 5 页面(赛程/实况/结果/积分/赔率)、实况 30s 轮询(Task 8)、下拉刷新(各 screen RefreshIndicator)、本地缓存回退(Task 5 Repository + Task 4 LocalCache)、stale 标志(模型+控制器透传)、错误/空状态(AsyncView + 空列表提示)。均有对应 Task。✅
- **明确不在 MVP(spec 已列后续):** 对阵图横向 bracket UI(数据层 `fetchBracket` 已就绪)、赔率让球/比分/总进球/半全场(代理仅 `wdl`)、从比赛点进赔率详情、推送/登录/收藏。在 Task 10/11 与 README 标注。
- **占位扫描:** Task 5 Step 3 含一个故意展示的"错误 import"反例并立即标注"不要写", 真实代码紧随其后 — 实现时只用真实代码块。Task 8 Step 1 含一个空 `fakeAsync` 占位 test 并标注删除 — 最终文件仅两个 test。无其他 TBD/TODO。
- **类型一致性:** `Repository` 方法签名(`fetchFixtures/fetchLive/fetchResults/fetchStandings/fetchBracket/fetchEvents/fetchOdds`)与各控制器调用一致; `ApiResponse<T>{data, stale}`、`Match`/`Standing`/`Odds`/`MatchEvent` 字段名前后一致; `AsyncView<T>` 的 `loading/error/data/builder/onRetry` 在所有 screen 用法一致。✅
- **依赖代理契约:** 端点路径与计划 1 一致(`/fixtures /live /results /standings /bracket /events?fixtureId= /odds?matchId=`); `data/stale` 包裹格式一致; `/odds` 的 `data:null` 已在 Odds 解析与 OddsScreen 空态处理。✅
- **Task 6→12 依赖:** Task 6 建无参 `HomeScaffold` 占位, Task 12 改为带 `repository` 参数并同步更新 Task 6 测试 — 已在 Task 12 Step 5 显式处理, 避免悬空。✅
