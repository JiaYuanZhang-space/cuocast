class ApiResponse<T> {
  final T data;
  final bool stale;
  ApiResponse({required this.data, required this.stale});

  factory ApiResponse.fromJson(
      Map<String, dynamic> json, T Function(dynamic data) parse) {
    return ApiResponse(data: parse(json['data']), stale: json['stale'] == true);
  }
}
