import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../auth/session_store.dart';
import '../config/app_config.dart';
import '../models/app_models.dart';
import '../utils/user_friendly_error.dart';

class SenderWhoRequestException implements Exception {
  const SenderWhoRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DashboardSummary {
  const DashboardSummary({
    required this.available,
    required this.inboxHealthScore,
    required this.inboxHealthStatus,
    required this.totalMessages,
    required this.totalSenders,
    required this.unreadEmails,
    required this.newsletters,
    required this.promotions,
    required this.spam,
    required this.topSenders,
    required this.recentAlerts,
    this.openAlertCount = 0,
    required this.cleanupMessages,
    required this.estimatedSpaceBytes,
    required this.unsubscribeSenders,
    required this.syncStatus,
    required this.syncError,
    this.syncRecoveryAction = 'NONE',
    required this.connectedAccountId,
    required this.connectedEmail,
    required this.lastSyncedAt,
  });

  final bool available;
  final int inboxHealthScore;
  final String inboxHealthStatus;
  final int totalMessages;
  final int totalSenders;
  final int unreadEmails;
  final int newsletters;
  final int promotions;
  final int spam;
  final List<TopSenderItem> topSenders;
  final List<AlertItem> recentAlerts;
  final int openAlertCount;
  final int cleanupMessages;
  final int estimatedSpaceBytes;
  final int unsubscribeSenders;
  final String? syncStatus;
  final String? syncError;
  final String syncRecoveryAction;
  final String? connectedAccountId;
  final String? connectedEmail;
  final DateTime? lastSyncedAt;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final inboxHealth = json['inboxHealth'] as Map<String, dynamic>? ?? {};
    final metrics = json['metrics'] as Map<String, dynamic>? ?? {};
    final alerts = _itemsFrom(
      json['recentAlerts'],
    ).map(AlertItem.fromJson).toList();
    final topSenders = _itemsFrom(
      json['topSenders'],
    ).map(TopSenderItem.fromJson).toList();
    final opportunities = json['opportunities'] as Map<String, dynamic>? ?? {};
    final sync = json['sync'] as Map<String, dynamic>?;

    return DashboardSummary(
      available: true,
      inboxHealthScore: (inboxHealth['score'] as num?)?.round() ?? 0,
      inboxHealthStatus:
          (inboxHealth['status'] as String?) ?? 'Waiting for scan',
      totalMessages: (metrics['totalMessages'] as num?)?.round() ?? 0,
      totalSenders: (metrics['totalSenders'] as num?)?.round() ?? 0,
      unreadEmails: (metrics['unreadEmails'] as num?)?.round() ?? 0,
      newsletters: (metrics['newsletters'] as num?)?.round() ?? 0,
      promotions: (metrics['promotions'] as num?)?.round() ?? 0,
      spam: (metrics['spam'] as num?)?.round() ?? 0,
      topSenders: topSenders,
      recentAlerts: alerts,
      openAlertCount:
          (json['openAlertCount'] as num?)?.round() ?? alerts.length,
      cleanupMessages: (opportunities['cleanupMessages'] as num?)?.round() ?? 0,
      estimatedSpaceBytes:
          (opportunities['estimatedSpaceBytes'] as num?)?.round() ?? 0,
      unsubscribeSenders:
          (opportunities['unsubscribeSenders'] as num?)?.round() ?? 0,
      syncStatus: sync?['syncStatus'] as String?,
      syncError: switch (sync?['lastSyncError']) {
        final String message when message.trim().isNotEmpty =>
          sanitizeUserMessage(
            message,
            fallback:
                'Email syncing needs attention. Reconnect the account or try again.',
          ),
        _ => null,
      },
      syncRecoveryAction: (sync?['recoveryAction'] as String?) ?? 'NONE',
      connectedAccountId: sync?['id'] as String?,
      connectedEmail: sync?['emailAddress'] as String?,
      lastSyncedAt: DateTime.tryParse((sync?['lastSyncedAt'] as String?) ?? ''),
    );
  }

  factory DashboardSummary.preview() {
    return DashboardSummary(
      available: true,
      inboxHealthScore: 86,
      inboxHealthStatus: 'Healthy inbox',
      totalMessages: 5003,
      totalSenders: 285,
      unreadEmails: 612,
      newsletters: 178,
      promotions: 342,
      spam: 31,
      topSenders: const [
        TopSenderItem(
          rank: 1,
          name: 'Canva',
          email: 'design@canva.com',
          count: 248,
        ),
        TopSenderItem(
          rank: 2,
          name: 'LinkedIn',
          email: 'updates@linkedin.com',
          count: 196,
        ),
        TopSenderItem(
          rank: 3,
          name: 'Amazon',
          email: 'shipment-tracking@amazon.com',
          count: 154,
        ),
      ],
      recentAlerts: [
        AlertItem.fromJson({
          'title': 'Review unusual sender',
          'email': 'security-update@example.net',
          'reason': 'Sender identity needs confirmation',
          'time': '18 minutes ago',
          'risk': 'Medium Risk',
          'colorKey': 'warning',
        }),
        AlertItem.fromJson({
          'title': 'Suspicious promotion',
          'email': 'rewards@example.org',
          'reason': 'Low sender trust score',
          'time': '2 hours ago',
          'risk': 'High Risk',
          'colorKey': 'danger',
        }),
      ],
      cleanupMessages: 1248,
      estimatedSpaceBytes: 734003200,
      unsubscribeSenders: 47,
      syncStatus: 'READY',
      syncError: null,
      connectedAccountId: 'ui-preview-account',
      connectedEmail: 'UI preview',
      lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 4)),
    );
  }

  static DashboardSummary fallback() {
    return const DashboardSummary(
      available: false,
      inboxHealthScore: 0,
      inboxHealthStatus: 'Waiting for scan',
      totalMessages: 0,
      totalSenders: 0,
      unreadEmails: 0,
      newsletters: 0,
      promotions: 0,
      spam: 0,
      topSenders: [],
      recentAlerts: [],
      cleanupMessages: 0,
      estimatedSpaceBytes: 0,
      unsubscribeSenders: 0,
      syncStatus: null,
      syncError: null,
      syncRecoveryAction: 'NONE',
      connectedAccountId: null,
      connectedEmail: null,
      lastSyncedAt: null,
    );
  }
}

class SenderWhoRepository {
  SenderWhoRepository({
    http.Client? client,
    SessionStore? sessionStore,
    Future<bool> Function(Uri uri)? launchExternal,
    bool? previewMode,
    this.baseUrl = AppConfig.apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _sessionStore = sessionStore ?? SecureSessionStore(),
       previewMode = previewMode ?? AppConfig.uiPreviewMode,
       _launchExternal =
           launchExternal ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  final http.Client _client;
  final SessionStore _sessionStore;
  final Future<bool> Function(Uri uri) _launchExternal;
  final bool previewMode;
  final String baseUrl;
  String? _accessToken;
  String? _refreshToken;
  String? _userEmail;
  String? _deviceId;
  String? _lastError;
  Future<bool>? _refreshInFlight;
  Future<bool>? _oauthInFlight;
  int _oauthAttempt = 0;
  final ValueNotifier<bool> authenticationState = ValueNotifier(false);

  bool get isAuthenticated => _refreshToken != null;
  String? get userEmail => previewMode ? 'UI preview' : _userEmail;
  String? get lastError => _lastError;

  Future<String?> rememberedEmail() async {
    try {
      return await _sessionStore.readRememberedEmail();
    } on Object {
      return null;
    }
  }

  Future<Map<String, bool>> availableAuthProviders() async {
    if (previewMode) return const {'google': true, 'yahoo': true};
    final json = await _requestJson(
      'GET',
      'auth/providers',
      authenticated: false,
      allowRefresh: false,
      allowStepUp: false,
    );
    final providers = json?['providers'];
    _lastError = null;
    if (providers is! Map<String, dynamic>) {
      return const {'google': true, 'yahoo': false};
    }
    bool enabled(String provider, {required bool fallback}) {
      final value = providers[provider];
      return value is Map<String, dynamic>
          ? value['enabled'] == true
          : fallback;
    }

    return {
      'google': enabled('google', fallback: true),
      'yahoo': enabled('yahoo', fallback: false),
    };
  }

  void cancelOAuth() {
    _oauthAttempt += 1;
    _lastError = 'Sign-in was canceled.';
  }

  Future<bool> restoreSession() async {
    try {
      await _ensureDeviceId();
      _refreshToken = await _sessionStore.readRefreshToken();
    } on Object catch (error) {
      debugPrint('Could not read the secure session: $error');
      _refreshToken = null;
      authenticationState.value = false;
      return false;
    }
    if (_refreshToken == null) return false;
    return _refreshSession();
  }

  Future<void> logout() async {
    final refreshToken = _refreshToken;
    if (refreshToken != null) {
      await _requestJson(
        'POST',
        'auth/logout',
        body: {'refreshToken': refreshToken},
        authenticated: false,
        allowRefresh: false,
      );
    }
    await _clearSession();
  }

  Future<DashboardSummary> getDashboard() async {
    if (previewMode) return DashboardSummary.preview();
    final json = await _getJson('dashboard');
    if (json == null) return DashboardSummary.fallback();
    return DashboardSummary.fromJson(json);
  }

  Future<SenderPage?> getSenders({
    int page = 1,
    int limit = 25,
    String kind = 'ALL',
    String control = 'ALL',
    String query = '',
  }) async {
    final encoded = Uri(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        'kind': kind,
        'control': control,
        if (query.trim().isNotEmpty) 'query': query.trim(),
      },
    ).query;
    final json = await _getJson('senders?$encoded');
    return json == null ? null : SenderPage.fromJson(json);
  }

  Future<SenderDetails> getSenderDetails(String id) async {
    final json = await _getJson('senders/$id');
    if (json == null) throw StateError('Could not load sender details.');
    return SenderDetails.fromJson(json);
  }

  Future<List<TopSenderItem>> getTopSenders() async {
    final json = await _getRequiredJson('senders/top');
    final items = _itemsFrom(json['items']);
    return items.map(TopSenderItem.fromJson).toList();
  }

  Future<SecurityAlertPage> getSecurityAlertsPage({
    int page = 1,
    int limit = 25,
  }) async {
    final json = await _getRequiredJson(
      'security-alerts?page=$page&limit=$limit',
    );
    return SecurityAlertPage.fromJson(json);
  }

  Future<List<AlertItem>> getSecurityAlerts() async {
    return (await getSecurityAlertsPage(limit: 100)).items;
  }

  Future<AlertItem> getSecurityAlert(String id) async {
    final json = await _getRequiredJson(
      'security-alerts/${Uri.encodeComponent(id)}',
    );
    return AlertItem.fromJson(json);
  }

  Future<InboxHealthSummary> getInboxHealth() async {
    if (previewMode) return _fallbackInboxHealth();
    final json = await _getRequiredJson('inbox-health');
    return InboxHealthSummary.fromJson(json);
  }

  Future<List<ConnectedEmailAccount>> getConnectedAccounts() async {
    final json = await _getRequiredJson('email-accounts');
    final items = _itemsFrom(json['items']);
    return items.map(ConnectedEmailAccount.fromJson).toList();
  }

  Future<List<CategoryItem>> getCategories() async {
    final json = await _getRequiredJson('categories');
    final items = _itemsFrom(json['items']);
    return items.map(CategoryItem.fromJson).toList();
  }

  Future<List<CleanupSuggestion>> getCleanupSuggestions() async {
    final json = await _getRequiredJson('cleanup/suggestions');
    final items = _itemsFrom(json['items']);
    return items.map(CleanupSuggestion.fromJson).toList();
  }

  Future<List<UnsubscribeCandidate>> getUnsubscribeCandidates() async {
    final json = await _getRequiredJson('unsubscribe/candidates');
    final items = _itemsFrom(json['items']);
    return items.map(UnsubscribeCandidate.fromJson).toList();
  }

  Future<List<EmailItem>> getPromotionEmails() async {
    final json = await _getRequiredJson('emails/promotions');
    final items = _itemsFrom(json['items']);
    return items.map(EmailItem.fromJson).toList();
  }

  Future<EmailPage?> getEmails({
    int page = 1,
    int limit = 25,
    String mailbox = 'INBOX',
    String? query,
    String? category,
    String? cleanupCategory,
    String? senderId,
    bool? hasAttachments,
  }) async {
    final parameters = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'mailbox': mailbox,
    };
    if (query?.trim().isNotEmpty == true) parameters['query'] = query!.trim();
    if (category?.isNotEmpty == true) parameters['category'] = category!;
    if (cleanupCategory?.isNotEmpty == true) {
      parameters['cleanupCategory'] = cleanupCategory!;
    }
    if (senderId?.isNotEmpty == true) parameters['senderId'] = senderId!;
    if (hasAttachments != null) {
      parameters['hasAttachments'] = '$hasAttachments';
    }
    final encoded = Uri(queryParameters: parameters).query;
    final json = await _getJson('emails?$encoded');
    return json == null ? null : EmailPage.fromJson(json);
  }

  Future<EmailItem?> getEmail(String id) async {
    final json = await _getJson('emails/${Uri.encodeComponent(id)}');
    return json == null ? null : EmailItem.fromJson(json);
  }

  Future<EmailThread?> getEmailThread(String id) async {
    final json = await _getJson('emails/${Uri.encodeComponent(id)}/thread');
    return json == null ? null : EmailThread.fromJson(json);
  }

  Future<EmailContent?> getEmailContent(String id) async {
    final json = await _getJson('emails/${Uri.encodeComponent(id)}/content');
    return json == null ? null : EmailContent.fromJson(json);
  }

  Future<ActivityInsights> getActivityInsights() async {
    if (previewMode) return _fallbackActivityInsights();
    final json = await _getRequiredJson('activity');
    return ActivityInsights.fromJson(json);
  }

  Future<AppSettings> getSettings() async {
    if (previewMode) return _fallbackSettings();
    final json = await _getRequiredJson('settings');
    return AppSettings.fromJson(json);
  }

  Future<PrivacySecuritySummary> getPrivacySecurity() async {
    if (previewMode) return _fallbackPrivacySecurity();
    final json = await _getRequiredJson('privacy-security');
    return PrivacySecuritySummary.fromJson(json);
  }

  Future<SearchFilterOptions> getSearchFilterOptions() async {
    if (previewMode) return _fallbackSearchFilters();
    final json = await _getRequiredJson('search/filters');
    final options = SearchFilterOptions.fromJson(json);
    if (options.categories.isEmpty) return _fallbackSearchFilters();
    return options;
  }

  Future<SearchResults?> search({
    required String query,
    required Set<String> selected,
    required bool attachments,
    required bool unread,
    int page = 1,
    int limit = 25,
  }) async {
    final json = await _postJson(
      'search',
      body: {
        'query': query,
        'selected': selected.toList(),
        'hasAttachments': attachments,
        'unreadOnly': unread,
        'page': page,
        'limit': limit,
      },
    );
    return json == null ? null : SearchResults.fromJson(json);
  }

  Future<AppSettings?> updatePreferences({
    bool? notificationsEnabled,
    String? inboxScanFrequency,
    String? theme,
  }) async {
    final body = <String, Object?>{};
    if (notificationsEnabled != null) {
      body['notificationsEnabled'] = notificationsEnabled;
    }
    if (inboxScanFrequency != null) {
      body['inboxScanFrequency'] = inboxScanFrequency;
    }
    if (theme != null) body['theme'] = theme;
    final json = await _patchJson('settings/preferences', body: body);
    return json == null ? null : AppSettings.fromJson(json);
  }

  Future<bool> startOAuth(String provider) async {
    return _runOAuth(() => _startOAuth(provider, useRememberedLoginHint: true));
  }

  Future<bool> startOAuthWithAccountChooser(String provider) {
    return _runOAuth(() => _startOAuth(provider));
  }

  Future<bool> reauthenticate() => _runOAuth(
    () => _startOAuth(
      'google',
      startPath: 'auth/reauth/google/start',
      authenticatedStart: true,
    ),
  );

  Future<bool> _runOAuth(Future<bool> Function() start) async {
    final existing = _oauthInFlight;
    if (existing != null) return existing;

    final operation = start();
    _oauthInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_oauthInFlight, operation)) _oauthInFlight = null;
    }
  }

  Future<bool> _startOAuth(
    String provider, {
    String? startPath,
    bool authenticatedStart = false,
    String? loginHint,
    bool useRememberedLoginHint = false,
  }) async {
    final attempt = ++_oauthAttempt;
    final resolvedLoginHint = useRememberedLoginHint
        ? await rememberedEmail()
        : loginHint;
    if (attempt != _oauthAttempt) return false;
    final json = await _requestJson(
      'POST',
      startPath ?? 'auth/oauth/$provider/start',
      body: resolvedLoginHint?.isNotEmpty == true
          ? {'loginHint': resolvedLoginHint}
          : null,
      authenticated: authenticatedStart,
      allowRefresh: false,
    );
    final authorizationUrl = json?['authorizationUrl'] as String?;
    final sessionId = json?['loginSessionId'] as String?;
    final sessionSecret = json?['loginSessionSecret'] as String?;
    if (authorizationUrl == null ||
        sessionId == null ||
        sessionSecret == null) {
      _lastError ??= '${_providerName(provider)} sign-in could not be started.';
      return false;
    }

    if (attempt != _oauthAttempt) return false;

    final uri = Uri.tryParse(authorizationUrl);
    if (uri == null) {
      _lastError =
          'The ${_providerName(provider)} authorization address is invalid.';
      return false;
    }
    final opened = await _launchExternal(uri);
    if (!opened) {
      _lastError =
          'Could not open ${_providerName(provider)} sign-in on this device.';
      return false;
    }

    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (attempt == _oauthAttempt && DateTime.now().isBefore(deadline)) {
      // This polls only SenderWho's short-lived login session; it does not
      // send repeated authorization requests to Google. A two-second interval
      // also keeps the unauthenticated API traffic comfortably rate-limited.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (attempt != _oauthAttempt) return false;
      final exchange = await _requestJson(
        'POST',
        'auth/oauth/session/exchange',
        body: {'sessionId': sessionId, 'sessionSecret': sessionSecret},
        authenticated: false,
        allowRefresh: false,
      );
      final status = exchange?['status'] as String?;
      if (status == 'PENDING') continue;
      if (exchange == null) {
        if (_lastError == 'The server took too long to respond.' ||
            _lastError == 'Could not connect to the SenderWho API.') {
          continue;
        }
        return false;
      }
      if (status == 'FAILED') {
        _lastError =
            (exchange['error'] as String?) ??
            '${_providerName(provider)} sign-in failed.';
        return false;
      }
      if (status == 'AUTHENTICATED') {
        return _acceptSession(exchange);
      }
      if (status == 'REAUTHENTICATED' && authenticatedStart) {
        final accessToken = exchange['accessToken'] as String?;
        if (accessToken == null || _refreshToken == null) {
          _lastError = 'Recent authentication could not update this session.';
          return false;
        }
        _accessToken = accessToken;
        final user = exchange['user'] as Map<String, dynamic>?;
        _userEmail = user?['email'] as String? ?? _userEmail;
        return true;
      }
      _lastError =
          '${_providerName(provider)} sign-in returned an unexpected response.';
      return false;
    }
    if (attempt == _oauthAttempt) {
      _lastError =
          '${_providerName(provider)} sign-in did not finish. Return to the app and try again.';
    }
    return false;
  }

  String _providerName(String provider) =>
      provider.toLowerCase() == 'yahoo' ? 'Yahoo' : 'Google';

  Future<bool> queueAccountSync(String id) async {
    final json = await _postJson('email-accounts/$id/sync');
    return json != null;
  }

  Future<DisconnectAccountResult?> disconnectAccount(String id) async {
    final json = await _deleteJson('email-accounts/$id');
    return json == null ? null : DisconnectAccountResult.fromJson(json);
  }

  Future<CleanupJobInfo?> createCleanupJob({
    required String emailAccountId,
    required List<String> categories,
    required String previewId,
  }) async {
    if (emailAccountId.isEmpty || categories.isEmpty || previewId.isEmpty) {
      return null;
    }
    final json = await _postJson(
      'cleanup/jobs',
      body: {
        'emailAccountId': emailAccountId,
        'categories': categories,
        'previewId': previewId,
      },
    );
    return json == null ? null : CleanupJobInfo.fromJson(json);
  }

  Future<CleanupPreview?> previewCleanup({
    required String emailAccountId,
    required List<String> categories,
  }) async {
    if (emailAccountId.isEmpty || categories.isEmpty) return null;
    final json = await _postJson(
      'cleanup/preview',
      body: {'emailAccountId': emailAccountId, 'categories': categories},
    );
    return json == null ? null : CleanupPreview.fromJson(json);
  }

  Future<CleanupJobInfo?> getCleanupJob(String id) async {
    final json = await _getJson('cleanup/jobs/${Uri.encodeComponent(id)}');
    return json == null ? null : CleanupJobInfo.fromJson(json);
  }

  Future<List<CleanupJobInfo>> getActiveCleanupJobs() async {
    final json = await _getRequiredJson('cleanup/jobs');
    final items = _itemsFrom(json['items']);
    return items.map(CleanupJobInfo.fromJson).toList();
  }

  Future<MessageActionResult?> applyEmailAction(
    String action,
    List<String> messageIds, {
    bool? isRead,
  }) async {
    if (messageIds.isEmpty) return null;
    final body = <String, Object?>{'messageIds': messageIds};
    if (isRead != null) body['isRead'] = isRead;
    final json = await _postJson('emails/actions/$action', body: body);
    return json == null ? null : MessageActionResult.fromJson(json);
  }

  Future<MessageActionResult?> archiveEmails(List<String> messageIds) {
    return applyEmailAction('archive', messageIds);
  }

  Future<MessageActionResult?> unarchiveEmails(List<String> messageIds) {
    return applyEmailAction('unarchive', messageIds);
  }

  Future<MessageActionResult?> trashEmails(List<String> messageIds) {
    return applyEmailAction('trash', messageIds);
  }

  Future<MessageActionResult?> restoreEmails(List<String> messageIds) {
    return applyEmailAction('restore', messageIds);
  }

  Future<MessageActionResult?> setEmailsRead(
    List<String> messageIds,
    bool isRead,
  ) {
    return applyEmailAction('read-state', messageIds, isRead: isRead);
  }

  Future<UnsubscribeJobInfo?> createUnsubscribeJob(String senderId) async {
    final json = await _postJson(
      'unsubscribe/jobs',
      body: {'senderId': senderId},
    );
    return json == null ? null : UnsubscribeJobInfo.fromJson(json);
  }

  Future<UnsubscribeBatchResult?> createUnsubscribeJobs(
    List<String> senderIds,
  ) async {
    final json = await _postJson(
      'unsubscribe/jobs/batch',
      body: {'senderIds': senderIds},
    );
    return json == null ? null : UnsubscribeBatchResult.fromJson(json);
  }

  Future<UnsubscribeJobInfo?> getUnsubscribeJob(String id) async {
    final json = await _getJson('unsubscribe/jobs/${Uri.encodeComponent(id)}');
    return json == null ? null : UnsubscribeJobInfo.fromJson(json);
  }

  Future<List<UnsubscribeJobInfo>> getUnsubscribeJobs(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final json = await _postJson(
      'unsubscribe/jobs/status',
      body: {'jobIds': ids},
    );
    if (json == null) {
      throw SenderWhoRequestException(
        _lastError ?? 'Unsubscribe progress could not be refreshed.',
      );
    }
    return _itemsFrom(json['items']).map(UnsubscribeJobInfo.fromJson).toList();
  }

  Future<List<UnsubscribeJobInfo>> getActiveUnsubscribeJobs() async {
    final json = await _getRequiredJson('unsubscribe/jobs');
    return _itemsFrom(json['items']).map(UnsubscribeJobInfo.fromJson).toList();
  }

  Future<bool> setSenderBlocked(String id, bool blocked) async {
    final json = await _patchJson(
      'senders/$id/block',
      body: {'blocked': blocked},
    );
    return json != null;
  }

  Future<bool> setSenderTrusted(String id, bool trusted) async {
    final json = await _patchJson(
      'senders/$id/trust',
      body: {'trusted': trusted},
    );
    return json != null;
  }

  Future<bool> resolveSecurityAlert(String id) async {
    final json = await _patchJson('security-alerts/$id/resolve');
    return json != null;
  }

  Future<bool> dismissSecurityAlert(String id) async {
    final json = await _patchJson('security-alerts/$id/dismiss');
    return json != null;
  }

  Future<List<AppSessionInfo>> getSessions() async {
    final json = await _getRequiredJson('auth/sessions');
    return _itemsFrom(json['items']).map(AppSessionInfo.fromJson).toList();
  }

  Future<bool> revokeSession(String id) async {
    final json = await _deleteJson('auth/sessions/${Uri.encodeComponent(id)}');
    if (json?['revokedCurrent'] == true) await _clearSession();
    return json != null;
  }

  Future<int?> revokeAllSessions() async {
    final json = await _postJson('auth/sessions/revoke-all');
    if (json == null) return null;
    final count = (json['revokedSessions'] as num?)?.round() ?? 0;
    await _clearSession();
    return count;
  }

  Future<Map<String, dynamic>?> exportData({
    String section = 'profile',
    int page = 1,
    int limit = 100,
  }) {
    final query = Uri(
      queryParameters: {'section': section, 'page': '$page', 'limit': '$limit'},
    ).query;
    return _getJson('users/me/export?$query');
  }

  Future<Map<String, dynamic>> prepareCompleteExport() async {
    const sections = [
      'profile',
      'accounts',
      'senders',
      'messages',
      'alerts',
      'audit',
    ];
    final export = <String, dynamic>{
      'format': 'senderwho-data-export',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sections': <String, dynamic>{},
    };
    final outputSections = export['sections']! as Map<String, dynamic>;
    for (final section in sections) {
      final items = <Object?>[];
      var page = 1;
      while (true) {
        final query = Uri(
          queryParameters: {
            'section': section,
            'page': '$page',
            'limit': '250',
          },
        ).query;
        final response = await _getRequiredJson('users/me/export?$query');
        final pageItems = response['items'];
        if (pageItems is List) items.addAll(pageItems);
        if (response['hasMore'] != true) break;
        page += 1;
        if (page > 10000) {
          throw const SenderWhoRequestException(
            'The export is too large to prepare safely on this device.',
          );
        }
      }
      outputSections[section] = items;
    }
    return export;
  }

  Future<bool> deleteAccount() async {
    final json = await _deleteJson('users/me');
    if (json == null) return false;
    await _clearSession();
    return true;
  }

  Future<Map<String, dynamic>?> _getJson(String path) {
    return _requestJson('GET', path);
  }

  Future<Map<String, dynamic>> _getRequiredJson(String path) async {
    final json = await _getJson(path);
    if (json != null) return json;
    throw SenderWhoRequestException(
      _lastError ?? 'SenderWho could not load this information.',
    );
  }

  Future<Map<String, dynamic>?> _postJson(
    String path, {
    Map<String, Object?>? body,
  }) {
    return _sendJson('POST', path, body: body);
  }

  Future<Map<String, dynamic>?> _patchJson(
    String path, {
    Map<String, Object?>? body,
  }) {
    return _sendJson('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>?> _deleteJson(String path) {
    return _sendJson('DELETE', path);
  }

  Future<Map<String, dynamic>?> _sendJson(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    return _requestJson(
      method,
      path,
      body: body,
      idempotencyKey: _newIdempotencyKey(),
    );
  }

  Future<Map<String, dynamic>?> _requestJson(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
    bool allowRefresh = true,
    bool allowStepUp = true,
    String? idempotencyKey,
  }) async {
    try {
      _lastError = null;
      final request = http.Request(method, Uri.parse('$baseUrl/$path'));
      request.headers['Content-Type'] = 'application/json';
      final deviceId = await _ensureDeviceId();
      request.headers['X-SenderWho-Device-Id'] = deviceId;
      request.headers['X-SenderWho-Device-Name'] = _deviceName();
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }
      if (authenticated && _accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 && authenticated && allowStepUp) {
        final message = _errorMessageFromResponse(response);
        if (message.contains('Recent authentication is required')) {
          _lastError = message;
          if (await reauthenticate()) {
            return _requestJson(
              method,
              path,
              body: body,
              authenticated: true,
              allowRefresh: allowRefresh,
              allowStepUp: false,
              idempotencyKey: idempotencyKey,
            );
          }
          return null;
        }
      }
      if (response.statusCode == 401 &&
          authenticated &&
          allowRefresh &&
          await _refreshSession()) {
        return _requestJson(
          method,
          path,
          body: body,
          authenticated: true,
          allowRefresh: false,
          allowStepUp: allowStepUp,
          idempotencyKey: idempotencyKey,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = _errorMessageFromResponse(response);
        return null;
      }
      if (response.body.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on TimeoutException {
      _lastError = 'The server took too long to respond.';
      return null;
    } on Object {
      _lastError = 'Could not connect to the SenderWho API.';
      return null;
    }
  }

  Future<bool> _refreshSession() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/auth/refresh'));
      request.headers['Content-Type'] = 'application/json';
      final deviceId = await _ensureDeviceId();
      request.headers['X-SenderWho-Device-Id'] = deviceId;
      request.headers['X-SenderWho-Device-Name'] = _deviceName();
      request.body = jsonEncode({'refreshToken': refreshToken});
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _clearSession();
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['status'] != 'AUTHENTICATED') {
        return false;
      }
      return _acceptSession(decoded);
    } on Object {
      return false;
    }
  }

  Future<bool> _acceptSession(Map<String, dynamic> json) async {
    final accessToken = json['accessToken'] as String?;
    final refreshToken = json['refreshToken'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    if (accessToken == null || refreshToken == null) return false;

    try {
      // Persist first so the repository never reports an authenticated session
      // that cannot survive an app restart.
      await _sessionStore.writeRefreshToken(refreshToken);
    } on Object catch (error) {
      debugPrint('Could not save the secure session: $error');
      _lastError = 'The secure session could not be saved on this device.';
      return false;
    }

    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userEmail = user?['email'] as String?;
    final email = _userEmail;
    if (email != null && email.isNotEmpty) {
      try {
        await _sessionStore.writeRememberedEmail(email);
      } on Object catch (error) {
        debugPrint('Could not remember the account email: $error');
      }
    }
    authenticationState.value = true;
    return true;
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _userEmail = null;
    authenticationState.value = false;
    try {
      await _sessionStore.clear();
    } on Object catch (error) {
      debugPrint('Could not clear the secure session: $error');
    }
  }

  Future<String> _ensureDeviceId() async {
    final current = _deviceId;
    if (current != null) return current;
    String? stored;
    try {
      stored = await _sessionStore.readDeviceId().timeout(
        const Duration(seconds: 2),
      );
    } on Object catch (error) {
      debugPrint('Could not read the secure device identity: $error');
    }
    if (stored != null && stored.length >= 20) {
      _deviceId = stored;
      return stored;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final generated = base64UrlEncode(bytes).replaceAll('=', '');
    _deviceId = generated;
    try {
      await _sessionStore
          .writeDeviceId(generated)
          .timeout(const Duration(seconds: 2));
    } on Object catch (error) {
      // Device identity improves session history and rate-limit attribution but
      // is not an authentication secret. Keep the process-local value so a
      // storage outage cannot freeze the application.
      debugPrint('Could not persist the secure device identity: $error');
    }
    return generated;
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _deviceName() {
    if (kIsWeb) return 'Web browser';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android device',
      TargetPlatform.iOS => 'iPhone or iPad',
      TargetPlatform.macOS => 'Mac',
      TargetPlatform.windows => 'Windows device',
      TargetPlatform.linux => 'Linux device',
      TargetPlatform.fuchsia => 'Fuchsia device',
    };
  }
}

String _errorMessageFromResponse(http.Response response) {
  String? serverMessage;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        serverMessage = message;
      } else if (message is List && message.isNotEmpty) {
        serverMessage = message.whereType<String>().join(', ');
      }
    }
  } on Object {
    // Use the status-based message below for non-JSON provider responses.
  }
  return friendlyHttpErrorMessage(
    response.statusCode,
    serverMessage: serverMessage,
  );
}

List<Map<String, dynamic>> _itemsFrom(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((item) {
    return item.map((key, value) => MapEntry('$key', value));
  }).toList();
}

final senderWhoRepository = SenderWhoRepository();

InboxHealthSummary _fallbackInboxHealth() {
  return const InboxHealthSummary(
    score: 0,
    status: 'Unavailable',
    breakdown: [],
  );
}

ActivityInsights _fallbackActivityInsights() {
  return const ActivityInsights(
    period: 'Unavailable',
    stats: [],
    weeklyActivity: [],
  );
}

AppSettings _fallbackSettings() {
  return AppSettings.fromJson({
    'account': {'connectedAccountsCount': 0},
    'preferences': {
      'notificationsEnabled': true,
      'inboxScanFrequency': 'Auto',
      'theme': 'System',
    },
    'emailManagement': {
      'archivedEmails': 0,
      'trashEmails': 0,
      'blockedSenders': 0,
    },
  });
}

PrivacySecuritySummary _fallbackPrivacySecurity() {
  return PrivacySecuritySummary.fromJson({
    'twoFactorEnabled': false,
    'blockedSenders': 0,
    'trustedSenders': 0,
    'dataRetention': 'Metadata only',
    'privacyMode': 'Standard',
  });
}

SearchFilterOptions _fallbackSearchFilters() {
  return SearchFilterOptions.fromJson({
    'categories': [
      'Marketing',
      'Newsletters',
      'Social',
      'Orders',
      'Finance',
      'Updates',
      'Spam',
    ],
    'trustScores': ['All', 'High (75+)', 'Medium (50-74)', 'Low (<50)'],
    'dateRanges': ['Any time', 'Today', 'This Week', 'This Month'],
  });
}
