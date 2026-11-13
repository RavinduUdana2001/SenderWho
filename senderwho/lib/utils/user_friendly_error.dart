const _fallbackMessage = 'Couldn’t complete that. Please try again.';

bool isMailboxRateLimited(String? value) => RegExp(
  r'(gmail is busy|temporarily limiting|rate.?limit|too many requests|daily (api|sync) limit)',
  caseSensitive: false,
).hasMatch(value ?? '');

bool isRecentAuthenticationRequired(String? value) => RegExp(
  r'recent authentication is required',
  caseSensitive: false,
).hasMatch(value ?? '');

String mailboxSyncError(String? value) {
  if (RegExp(
    r'(google access (expired|was revoked)|google account.*(reconnected|refresh token)|invalid_grant)',
    caseSensitive: false,
  ).hasMatch(value ?? '')) {
    return 'Gmail access changed. Sign in again to reconnect.';
  }
  if (isMailboxRateLimited(value)) {
    return (value?.toLowerCase().contains('daily') ?? false)
        ? 'Gmail’s daily sync limit was reached. Saved mail is available.'
        : 'Gmail is busy. Sync will resume later; saved mail is available.';
  }
  if (RegExp(
    r'Gmail (batch item|API request|batch request) failed with status 403',
    caseSensitive: false,
  ).hasMatch(value ?? '')) {
    return 'Reconnect Gmail and review permissions to resume syncing.';
  }
  return sanitizeUserMessage(
    value,
    fallback:
        'We couldn’t update this mailbox. Your saved mail is still available.',
  );
}

String userFriendlyErrorMessage(
  Object? error, {
  String fallback = _fallbackMessage,
}) {
  return sanitizeUserMessage(error?.toString(), fallback: fallback);
}

String sanitizeUserMessage(
  String? value, {
  String fallback = _fallbackMessage,
}) {
  final message = value?.trim() ?? '';
  if (message.isEmpty) return fallback;

  final normalized = message
      .replaceFirst(RegExp(r'^(Exception|Error):\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F\u202A-\u202E\u2066-\u2069]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (RegExp(
    r'(did not grant all required|missing (gmail|email|mailbox) permissions|insufficient.*scope)',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return 'Reconnect your mailbox and allow email access.';
  }
  if (RegExp(
    r'(timed?\s*out|timeout|connection refused|failed to fetch|network request failed|'
    r'failed host lookup|network is unreachable|no internet|connection reset|'
    r'could not connect to the SenderWho API)',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return 'Couldn’t connect. Check your connection and try again.';
  }
  final unsafe = RegExp(
    r'(stack trace|prisma|postgres|sqlstate|select\s.+from|insert\s+into|'
    r'update\s+\w+\s+set|node_modules|/src/|\.dart:\d+|localhost|'
    r'null check operator|type .+ is not a subtype|socketexception|'
    r'clientexception|formatException|internal server error|'
    r'\b\w*(Exception|Error)\b|bad state:|invalid argument(\(s\))?:|'
    r'errno|ENOTFOUND|EAI_AGAIN|ECONN\w+|/Users/|/var/|/home/|'
    r'<[^>]+>|api[_ -]?key|client[_ -]?secret|password\s*[:=]|'
    r'Bearer\s|access_token|refresh_token|SQL|P\d{4}|\bHTTP\s+\d{3}|status\s+\d{3}|'
    r'https?://|property .+ should not exist|invalid_grant|'
    r'\beyJ[A-Za-z0-9_-]+\.|[{}]|\bat \w+ \(.+:\d+)',
    caseSensitive: false,
  );
  if (unsafe.hasMatch(normalized) || normalized.length > 120) return fallback;
  return normalized;
}

String friendlyHttpErrorMessage(int statusCode, {String? serverMessage}) {
  switch (statusCode) {
    case 400:
    case 422:
      if (RegExp(
        r'property (emailAccountId|category|query|filter) should not exist',
        caseSensitive: false,
      ).hasMatch(serverMessage ?? '')) {
        return 'A service update is needed. Please contact support.';
      }
      return sanitizeUserMessage(
        serverMessage,
        fallback: 'Please check the information you entered and try again.',
      );
    case 401:
      if (isRecentAuthenticationRequired(serverMessage)) {
        return 'Please sign in again to confirm this action.';
      }
      if (RegExp(
        r'(google|gmail).*(revoked|reconnect|expired|refresh token)',
        caseSensitive: false,
      ).hasMatch(serverMessage ?? '')) {
        return 'Gmail access changed. Sign in again to reconnect.';
      }
      return 'Your session has expired. Please sign in again.';
    case 403:
      return 'Email access is missing. Please reconnect this mailbox.';
    case 404:
      return 'This item is no longer available. Refresh to see the latest data.';
    case 408:
    case 504:
      return 'The request took too long. Check your connection and try again.';
    case 409:
      return sanitizeUserMessage(
        serverMessage,
        fallback: 'This information changed recently. Refresh and try again.',
      );
    case 429:
      return 'Too many requests. Please wait a moment.';
    default:
      if (statusCode >= 500) {
        return 'SenderWho is temporarily unavailable. Please try again shortly.';
      }
      return sanitizeUserMessage(serverMessage);
  }
}
