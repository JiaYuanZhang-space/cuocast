import 'dart:convert';
import 'dart:io';
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
    } on ApiException {
      final cached = cache.read(cacheKey);
      if (cached != null) {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        return ApiResponse<T>(data: parse(json['data']), stale: true);
      }
      rethrow;
    } on SocketException {
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
