const _fallbackMessage =
    'Something went wrong. Check your connection and try again.';

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
      .trim();
  final unsafe = RegExp(
    r'(stack trace|prisma|postgres|sqlstate|select\s.+from|insert\s+into|'
    r'update\s+\w+\s+set|node_modules|/src/|\.dart:\d+|localhost|'
    r'null check operator|type .+ is not a subtype|socketexception|'
    r'clientexception|formatException|internal server error)',
    caseSensitive: false,
  );
  if (unsafe.hasMatch(normalized) || normalized.length > 220) return fallback;
  return normalized;
}

String friendlyHttpErrorMessage(int statusCode, {String? serverMessage}) {
  switch (statusCode) {
    case 400:
    case 422:
      return sanitizeUserMessage(
        serverMessage,
        fallback: 'Please check the information you entered and try again.',
      );
    case 401:
      return 'Your session has expired. Please connect your email again.';
    case 403:
      return 'SenderWho does not have permission to complete this action. '
          'Please reconnect your email account.';
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
      return 'SenderWho is temporarily waiting for your email provider. '
          'Please try again shortly.';
    default:
      if (statusCode >= 500) {
        return 'SenderWho is temporarily unavailable. Please try again shortly.';
      }
      return sanitizeUserMessage(serverMessage);
  }
}
