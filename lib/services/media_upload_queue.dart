import 'dart:async';
import 'dart:collection';

/// Limits concurrent Firebase Storage uploads per device to reduce OOM risk.
class MediaUploadQueue {
  MediaUploadQueue._();

  static final MediaUploadQueue instance = MediaUploadQueue._();

  static const int maxConcurrent = 2;

  int _activeCount = 0;
  final Queue<Future<void> Function()> _pending = Queue();

  Future<T> run<T>(Future<T> Function() task, {int maxAttempts = 3}) {
    final completer = Completer<T>();

    Future<void> execute() async {
      var attempt = 0;
      while (true) {
        attempt += 1;
        try {
          completer.complete(await task());
          return;
        } catch (error, stack) {
          if (attempt >= maxAttempts) {
            completer.completeError(error, stack);
            return;
          }
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }

    _pending.add(() async {
      try {
        await execute();
      } catch (error, stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      } finally {
        _activeCount -= 1;
        _pump();
      }
    });

    _pump();
    return completer.future;
  }

  void _pump() {
    while (_activeCount < maxConcurrent && _pending.isNotEmpty) {
      _activeCount += 1;
      final next = _pending.removeFirst();
      unawaited(next());
    }
  }
}
