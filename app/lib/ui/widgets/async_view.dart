import 'package:flutter/material.dart';

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
