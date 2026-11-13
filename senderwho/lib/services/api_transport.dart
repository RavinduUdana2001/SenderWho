import 'dart:async';
import 'package:http/http.dart' as http;

/// Cancels one read/search without closing the shared authenticated client.
class RequestCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  bool get isCancelled => _cancelled;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void Function() listen(void Function() callback) {
    if (_cancelled) {
      callback();
      return () {};
    }
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }
}

/// One deadline covers connection, response headers, and the entire body.
/// Timeout/cancellation also stops the body subscription and the real HTTP
/// request (IOClient/BrowserClient), rather than only abandoning its Future.
Future<http.Response> sendApiRequest(
  http.Client client,
  http.Request source, {
  required Duration timeout,
  RequestCancellation? cancellation,
}) async {
  final abortTrigger = Completer<void>();
  final request =
      http.AbortableRequest(
          source.method,
          source.url,
          abortTrigger: abortTrigger.future,
        )
        ..headers.addAll(source.headers)
        ..bodyBytes = source.bodyBytes;
  final completed = Completer<http.Response>();
  StreamSubscription<List<int>>? body;
  final bytes = <int>[];
  void stop(Object error) {
    if (completed.isCompleted) return;
    abortTrigger.complete();
    final cancel = body?.cancel();
    if (cancel != null) unawaited(cancel.catchError((Object _) {}));
    completed.completeError(error);
  }

  final timer = Timer(
    timeout,
    () => stop(TimeoutException('API request timed out', timeout)),
  );
  final remove = cancellation?.listen(
    () => stop(http.RequestAbortedException(source.url)),
  );
  if (!completed.isCompleted) {
    unawaited(() async {
      try {
        final response = await client.send(request);
        if (completed.isCompleted) {
          await response.stream.listen((_) {}, onError: (Object _) {}).cancel();
          return;
        }
        body = response.stream.listen(
          bytes.addAll,
          onError: (Object error, StackTrace trace) {
            if (!completed.isCompleted) completed.completeError(error, trace);
          },
          onDone: () {
            if (!completed.isCompleted) {
              completed.complete(
                http.Response.bytes(
                  bytes,
                  response.statusCode,
                  headers: response.headers,
                  request: request,
                  isRedirect: response.isRedirect,
                  persistentConnection: response.persistentConnection,
                  reasonPhrase: response.reasonPhrase,
                ),
              );
            }
          },
          cancelOnError: true,
        );
      } catch (error, trace) {
        if (!completed.isCompleted) completed.completeError(error, trace);
      }
    }());
  }
  try {
    return await completed.future;
  } finally {
    timer.cancel();
    remove?.call();
  }
}
