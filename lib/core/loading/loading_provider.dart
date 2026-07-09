import 'package:flutter_riverpod/flutter_riverpod.dart';

final loadingProvider = NotifierProvider<LoadingNotifier, bool>(
  LoadingNotifier.new,
);

class LoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void hide() => state = false;
}

extension LoadingRef on Ref {
  Future<T> withLoading<T>(Future<T> Function() task) async {
    read(loadingProvider.notifier).show();
    try {
      return await task();
    } finally {
      read(loadingProvider.notifier).hide();
    }
  }
}

extension LoadingWidgetRef on WidgetRef {
  Future<T> withLoading<T>(Future<T> Function() task) async {
    read(loadingProvider.notifier).show();
    try {
      return await task();
    } finally {
      read(loadingProvider.notifier).hide();
    }
  }
}
