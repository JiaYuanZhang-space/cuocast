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
