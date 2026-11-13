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
import 'api_transport.dart';

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
    this.syncRetryAt,
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
  final DateTime? syncRetryAt;
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
        final String message when message.trim().isNotEmpty => mailboxSyncError(
          message,
        ),
        _ => null,
      },
      syncRecoveryAction: (sync?['recoveryAction'] as String?) ?? 'NONE',
      syncRetryAt: DateTime.tryParse((sync?['syncRetryAt'] as String?) ?? ''),
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
    this.oauthPollInterval = const Duration(seconds: 2),
    this.requestTimeout = const Duration(seconds: 15),
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
  final Duration oauthPollInterval;
  final Duration requestTimeout;
  final String baseUrl;
  String? _accessToken;
  String? _refreshToken;
  String? _userEmail;
  String? _deviceId;
  String? _lastError;
  AppSettings? _previewSettings;
  Future<bool>? _refreshInFlight;
  Future<void> _sessionWrite = Future.value();
  Future<bool>? _oauthInFlight;
  int _oauthAttempt = 0;
  final ValueNotifier<bool> authenticationState = ValueNotifier(false);

  final userProfile = ValueNotifier<UserProfile?>(null);
  final connectedAccounts = ValueNotifier<List<ConnectedEmailAccount>>(
    const [],
  );
  final activeMailbox = ValueNotifier<ConnectedEmailAccount?>(null);
  final mailboxRevision = ValueNotifier<int>(0);
  final switchingMailbox = ValueNotifier<String?>(null);
  Future<bool>? _mailboxSwitchInFlight;
  Future<UserProfile?>? _profileInFlight;
  Future<List<ConnectedEmailAccount>>? _accountsInFlight;
  bool _mailboxContextLoaded = false;
  int _identityGeneration = 0;

  Future<UserProfile?> getUserProfile({bool refresh = false}) {
    if (!refresh && userProfile.value != null) {
      return Future.value(userProfile.value);
    }
    final existing = _profileInFlight;
    if (existing != null) return existing;
    final operation = _loadUserProfile();
    _profileInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_profileInFlight, operation)) _profileInFlight = null;
    });
  }

  Future<UserProfile?> _loadUserProfile() async {
    final generation = _identityGeneration;
    final json = await _getJson('auth/me');
    if (json == null || generation != _identityGeneration) return null;
    final profile = UserProfile.fromJson(json);
    if (profile.email.isEmpty) return null;
    userProfile.value = profile;
    return profile;
  }

  bool get isAuthenticated => _refreshToken != null;
  String? get userEmail => previewMode ? 'UI preview' : _userEmail;
  String? get lastError =>
      _lastError == null ? null : sanitizeUserMessage(_lastError);

  Future<String?> rememberedEmail() async {
    try {
      return await _sessionStore.readRememberedEmail();
    } on Object {
      return null;
    }
  }

  Future<String?> rememberedProvider() async {
    try {
      final provider = await _sessionStore.readRememberedProvider();
      final normalized = provider?.trim().toLowerCase();
      return switch (normalized) {
        'google' || 'microsoft' || 'yahoo' => normalized,
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  Future<Map<String, bool>> availableAuthProviders() async {
    if (previewMode) {
      return const {'google': true, 'microsoft': true, 'yahoo': true};
    }
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
      return const {'google': true, 'microsoft': false, 'yahoo': false};
    }
    bool enabled(String provider, {required bool fallback}) {
      final value = providers[provider];
      return value is Map<String, dynamic>
          ? value['enabled'] == true
          : fallback;
    }

    return {
      'google': enabled('google', fallback: true),
      'microsoft': enabled('microsoft', fallback: false),
      'yahoo': enabled('yahoo', fallback: false),
    };
  }

  void cancelOAuth() {
    _oauthAttempt += 1;
    _oauthInFlight = null;
    _lastError = 'Sign-in was canceled.';
  }

  Future<bool> restoreSession() async {
    final generation = _identityGeneration;
    try {
      return await (() async {
        await _ensureDeviceId();
        final saved = await _sessionStore.readRefreshToken();
        if (generation != _identityGeneration) return false;
        _refreshToken = saved;
        if (saved == null) return false;
        return _refreshSession();
      })().timeout(const Duration(seconds: 4));
    } on TimeoutException {
      // Show welcome within the launch budget. The refresh may still finish
      // and save rotated credentials; its identity/OAuth guards protect a new
      // sign-in. Never discard a rotated refresh token merely for a UI timeout.
      return false;
    } on Object catch (error) {
      debugPrint('Could not read the secure session: $error');
      _refreshToken = null;
      authenticationState.value = false;
      return false;
    }
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
    String? category,
  }) async {
    final encoded = Uri(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        'kind': kind,
        'control': control,
        if (activeMailbox.value case final mailbox?)
          'emailAccountId': mailbox.id,
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (category?.isNotEmpty == true) 'category': category!,
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

  Future<List<ConnectedEmailAccount>> getConnectedAccounts() {
    final pending = _accountsInFlight;
    if (pending != null) return pending;
    late final Future<List<ConnectedEmailAccount>> operation;
    operation = _loadConnectedAccounts().whenComplete(() {
      if (identical(_accountsInFlight, operation)) _accountsInFlight = null;
    });
    _accountsInFlight = operation;
    return operation;
  }

  Future<List<ConnectedEmailAccount>> _loadConnectedAccounts() async {
    final generation = _identityGeneration;
    final revision = mailboxRevision.value;
    Map<String, dynamic> json;
    try {
      json = await _getRequiredJson('email-accounts');
    } on Object {
      if (generation != _identityGeneration) return const [];
      if (revision != mailboxRevision.value) return connectedAccounts.value;
      rethrow;
    }
    if (generation != _identityGeneration) return const [];
    if (revision != mailboxRevision.value) return connectedAccounts.value;
    if (json['items'] is! List) {
      throw const SenderWhoRequestException(
        'Your mailboxes could not be loaded. Please try again.',
      );
    }
    final previousId = activeMailbox.value?.id;
    final wasLoaded = _mailboxContextLoaded;
    final items = _itemsFrom(json['items']);
    final accounts = items.map(ConnectedEmailAccount.fromJson).toList();
    connectedAccounts.value = List.unmodifiable(accounts);
    activeMailbox.value = accounts
        .where((account) => account.isActive)
        .firstOrNull;
    _mailboxContextLoaded = true;
    if (wasLoaded && previousId != activeMailbox.value?.id) {
      // Discovery can repair a missing/invalid primary or observe a selection
      // made on another device. Existing screens must not keep the old rows.
      mailboxRevision.value++;
    }
    return accounts;
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

  Future<UnsubscribeCandidatePage?> getUnsubscribePage({
    int page = 1,
    int limit = 25,
    String query = '',
    String filter = 'ALL',
    RequestCancellation? cancellation,
  }) async {
    final encoded = Uri(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        'filter': filter,
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (activeMailbox.value case final account?)
          'emailAccountId': account.id,
      },
    ).query;
    final json = await _requestJson(
      'GET',
      'unsubscribe/candidates?$encoded',
      cancellation: cancellation,
    );
    return json == null ? null : UnsubscribeCandidatePage.fromJson(json);
  }

  Future<List<UnsubscribeCandidate>> getUnsubscribeCandidates() async {
    final page = await getUnsubscribePage();
    if (page == null) {
      throw SenderWhoRequestException(
        lastError ?? 'Subscriptions could not be loaded.',
      );
    }
    return page.items;
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
      if (activeMailbox.value case final account?) 'emailAccountId': account.id,
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
    if (previewMode) return _previewSettings ??= _fallbackSettings();
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
    RequestCancellation? cancellation,
  }) async {
    final json = await _requestJson(
      'POST',
      'search',
      cancellation: cancellation,
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
    if (previewMode) {
      final current = await getSettings();
      return _previewSettings = current.copyWith(
        notificationsEnabled: notificationsEnabled,
        inboxScanFrequency: inboxScanFrequency,
        theme: theme,
      );
    }
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
    return _runOAuth(
      () => _startOAuth(
        provider,
        useRememberedLoginHint: provider.toLowerCase() != 'yahoo',
      ),
    );
  }

  Future<bool> startOAuthWithAccountChooser(String provider) {
    return _runOAuth(() => _startOAuth(provider));
  }

  Future<bool> connectEmailAccount(String provider, {String? loginHint}) =>
      _runOAuth(
        () => _startOAuth(
          provider,
          startPath: 'auth/connect/${provider.toLowerCase()}/start',
          authenticatedStart: true,
          loginHint: loginHint,
        ),
      );

  Future<bool> reauthenticate() => _runOAuth(
    () => _startOAuth(
      'google',
      startPath: 'auth/reauth/start',
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
    final normalizedProvider = provider.toLowerCase();
    final savedProvider = useRememberedLoginHint
        ? await rememberedProvider()
        : null;
    final resolvedLoginHint =
        useRememberedLoginHint && savedProvider == normalizedProvider
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
    final flowProvider = (json?['provider'] as String?) ?? provider;
    if (authorizationUrl == null ||
        sessionId == null ||
        sessionSecret == null) {
      _lastError ??=
          '${_providerName(flowProvider)} sign-in could not be started.';
      return false;
    }

    if (attempt != _oauthAttempt) return false;

    final uri = Uri.tryParse(authorizationUrl);
    if (uri == null) {
      _lastError =
          'The ${_providerName(flowProvider)} authorization address is invalid.';
      return false;
    }
    final opened = await _launchExternal(uri);
    if (!opened) {
      _lastError =
          'Could not open ${_providerName(flowProvider)} sign-in on this device.';
      return false;
    }

    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (attempt == _oauthAttempt && DateTime.now().isBefore(deadline)) {
      // This polls only SenderWho's short-lived login session; it does not
      // send repeated authorization requests to Google. A two-second interval
      // also keeps the unauthenticated API traffic comfortably rate-limited.
      await Future<void>.delayed(oauthPollInterval);
      if (attempt != _oauthAttempt) return false;
      final exchange = await _requestJson(
        'POST',
        'auth/oauth/session/exchange',
        body: {'sessionId': sessionId, 'sessionSecret': sessionSecret},
        authenticated: false,
        allowRefresh: false,
      );
      if (attempt != _oauthAttempt) return false;
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
            '${_providerName(flowProvider)} sign-in failed.';
        return false;
      }
      if (status == 'AUTHENTICATED') {
        return _acceptSession(
          exchange,
          provider: flowProvider,
          oauthAttempt: attempt,
        );
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
      if (status == 'ACCOUNT_CONNECTED' && authenticatedStart) {
        connectedAccounts.value = const [];
        activeMailbox.value = null;
        _mailboxContextLoaded = false;
        _accountsInFlight = null;
        try {
          await getConnectedAccounts();
        } on Object {
          // The account menu can retry discovery without repeating OAuth.
        }
        mailboxRevision.value++;
        return true;
      }
      _lastError =
          '${_providerName(flowProvider)} sign-in returned an unexpected response.';
      return false;
    }
    if (attempt == _oauthAttempt) {
      _lastError =
          '${_providerName(flowProvider)} sign-in did not finish. Return to the app and try again.';
    }
    return false;
  }

  String _providerName(String provider) => switch (provider.toLowerCase()) {
    'microsoft' => 'Microsoft Outlook',
    'yahoo' => 'Yahoo Mail',
    _ => 'Google',
  };

  Future<bool> queueAccountSync(String id) async {
    final json = await _postJson('email-accounts/$id/sync');
    return json != null;
  }

  Future<bool> activateEmailAccount(String id) {
    final pending = _mailboxSwitchInFlight;
    if (pending != null) {
      return switchingMailbox.value == id ? pending : Future.value(false);
    }
    final operation = _activateEmailAccount(id);
    _mailboxSwitchInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_mailboxSwitchInFlight, operation)) {
        _mailboxSwitchInFlight = null;
        switchingMailbox.value = null;
      }
    });
  }

  Future<bool> _activateEmailAccount(String id) async {
    switchingMailbox.value = id;
    final generation = _identityGeneration;
    // Keep the selected row while a concurrent account refresh replaces the
    // list. Activation must never succeed with an empty visible identity.
    final requested = connectedAccounts.value
        .where((account) => account.id == id)
        .firstOrNull;
    final json = await _postJson('email-accounts/$id/activate');
    if (generation != _identityGeneration) return false;
    if (json?['isActive'] != true || json?['id'] != id) {
      _lastError ??= 'Couldn’t switch mailboxes. Refresh your accounts.';
      return false;
    }
    final selected =
        connectedAccounts.value
            .where((account) => account.id == id)
            .firstOrNull ??
        requested ??
        ((json?['emailAddress'] as String?)?.trim().isNotEmpty == true
            ? ConnectedEmailAccount.fromJson(json!)
            : null);
    if (selected == null) {
      _lastError = 'Couldn’t switch mailboxes. Refresh your accounts.';
      return false;
    }
    final accounts = connectedAccounts.value
        .map(
          (account) => account.id == id
              ? selected.copyWith(isActive: true)
              : account.copyWith(isActive: false),
        )
        .toList();
    if (!accounts.any((account) => account.id == id)) {
      accounts.add(selected.copyWith(isActive: true));
    }
    connectedAccounts.value = List.unmodifiable(accounts);
    activeMailbox.value = selected.copyWith(isActive: true);
    _mailboxContextLoaded = true;
    mailboxRevision.value++;
    return true;
  }

  Future<DisconnectAccountResult?> disconnectAccount(String id) async {
    final json = await _deleteJson('email-accounts/$id');
    if (json == null) return null;
    final result = DisconnectAccountResult.fromJson(json);
    if (result.disconnected) {
      connectedAccounts.value = connectedAccounts.value
          .where((account) => account.id != id)
          .toList();
      if (activeMailbox.value?.id == id) activeMailbox.value = null;
      _mailboxContextLoaded = false;
      _accountsInFlight = null;
      mailboxRevision.value++;
    }
    return result;
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

  Future<CleanupJobInfo?> cancelCleanupJob(String id) async {
    if (id.isEmpty) return null;
    final json = await _postJson(
      'cleanup/jobs/${Uri.encodeComponent(id)}/cancel',
    );
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

  /// Applies an action to the complete, explicitly scoped result set.
  ///
  /// Message identifiers are resolved before mutation so provider-side changes
  /// cannot make pagination skip items. API action calls stay within the
  /// backend's 1,000-message batch limit.
  Future<MessageActionResult?> applyEmailActionToAllMatching(
    String action, {
    String mailbox = 'INBOX',
    String? query,
    String? category,
    String? cleanupCategory,
    String? senderId,
  }) async {
    const pageSize = 100;
    final resolvedIds = <String>{};
    var page = 1;
    while (true) {
      final result = await getEmails(
        page: page,
        limit: pageSize,
        mailbox: mailbox,
        query: query,
        category: category,
        cleanupCategory: cleanupCategory,
        senderId: senderId,
      );
      if (result == null) return null;
      resolvedIds.addAll(
        result.items.map((message) => message.id).where((id) => id.isNotEmpty),
      );
      if (!result.hasMore) break;
      page += 1;
    }

    final messageIds = resolvedIds.toList(growable: false);
    if (messageIds.isEmpty) {
      return MessageActionResult(
        action: action,
        requested: 0,
        processed: 0,
        failed: 0,
      );
    }

    final processedIds = <String>[];
    final failures = <MessageActionFailure>[];
    for (var start = 0; start < messageIds.length; start += 1000) {
      final end = start + 1000 < messageIds.length
          ? start + 1000
          : messageIds.length;
      final result = await applyEmailAction(
        action,
        messageIds.sublist(start, end),
      );
      if (result == null) {
        failures.addAll(
          messageIds
              .sublist(start, end)
              .map(
                (id) => MessageActionFailure(
                  messageId: id,
                  reason: _lastError ?? 'The email action failed.',
                ),
              ),
        );
        continue;
      }
      processedIds.addAll(result.processedIds);
      failures.addAll(result.failures);
    }
    return MessageActionResult(
      action: action,
      requested: messageIds.length,
      processed: processedIds.length,
      failed: failures.length,
      processedIds: processedIds,
      failures: failures,
    );
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
    final ids = senderIds.toSet().toList();
    final jobs = <UnsubscribeJobInfo>[];
    final failures = <UnsubscribeBatchFailure>[];
    final generation = _identityGeneration;
    final revision = mailboxRevision.value;
    for (var start = 0; start < ids.length; start += 25) {
      final batch = ids.skip(start).take(25).toList();
      Map<String, dynamic>? json;
      if (generation == _identityGeneration &&
          revision == mailboxRevision.value) {
        json = await _postJson(
          'unsubscribe/jobs/batch',
          body: {'senderIds': batch},
        );
      }
      if (json == null) {
        // Do not keep sending more mutations after a timeout, account switch,
        // or rate limit. Successful chunks remain successful; other rows retry.
        failures.addAll(
          ids
              .skip(start)
              .map(
                (id) => UnsubscribeBatchFailure(
                  senderId: id,
                  reason:
                      _lastError ??
                      'Request was not confirmed. Refresh progress before retrying.',
                ),
              ),
        );
        break;
      }
      final result = UnsubscribeBatchResult.fromJson(json);
      jobs.addAll(result.jobs);
      failures.addAll(result.failures);
    }
    return UnsubscribeBatchResult(jobs: jobs, failures: failures);
  }

  Future<UnsubscribeJobInfo?> getUnsubscribeJob(String id) async {
    final json = await _getJson('unsubscribe/jobs/${Uri.encodeComponent(id)}');
    return json == null ? null : UnsubscribeJobInfo.fromJson(json);
  }

  Future<List<UnsubscribeJobInfo>> getUnsubscribeJobs(List<String> ids) async {
    final unique = ids.toSet().toList();
    final jobs = <UnsubscribeJobInfo>[];
    for (var start = 0; start < unique.length; start += 25) {
      final json = await _postJson(
        'unsubscribe/jobs/status',
        body: {'jobIds': unique.skip(start).take(25).toList()},
      );
      if (json == null) {
        throw SenderWhoRequestException(
          _lastError ?? 'Unsubscribe progress could not be refreshed.',
        );
      }
      jobs.addAll(_itemsFrom(json['items']).map(UnsubscribeJobInfo.fromJson));
    }
    return jobs;
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

  Future<int?> revokeSessionsAfterProviderPasswordChange() async {
    final json = await _postJson(
      'auth/sessions/revoke-after-provider-password-change',
    );
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
    if (previewMode) {
      _lastError = 'Account deletion is unavailable in preview mode.';
      return false;
    }
    final json = await _deleteJson('users/me');
    if (json?['success'] != true) {
      _lastError ??=
          'Couldn’t delete your SenderWho account. Please try again.';
      return false;
    }
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
    RequestCancellation? cancellation,
  }) async {
    final generation = _identityGeneration;
    final revision = mailboxRevision.value;
    try {
      _lastError = null;
      var uri = Uri.parse('$baseUrl/$path');
      final endpoint = path.split('?').first;
      // Resolve (and, on the server, repair) the selected mailbox before any
      // mailbox list/count request. First login must not race account discovery.
      const mailboxReads = {
        'dashboard',
        'senders',
        'senders/top',
        'emails',
        'emails/promotions',
        'unsubscribe/candidates',
        'unsubscribe/jobs',
        'categories',
        'cleanup/suggestions',
        'cleanup/jobs',
        'activity',
        'inbox-health',
        'security-alerts',
        'search',
        'settings',
        'privacy-security',
      };
      if (authenticated &&
          (method == 'GET' || (method == 'POST' && endpoint == 'search')) &&
          isAuthenticated &&
          mailboxReads.contains(endpoint)) {
        if (!_mailboxContextLoaded && activeMailbox.value == null) {
          await getConnectedAccounts();
        }
        if (generation != _identityGeneration ||
            revision != mailboxRevision.value ||
            cancellation?.isCancelled == true) {
          return null;
        }
        // These list endpoints accept an explicit account. Add it after account
        // discovery, rather than encoding a null/default account before waiting.
        if (const {
              'senders',
              'emails',
              'unsubscribe/candidates',
            }.contains(endpoint) &&
            activeMailbox.value != null) {
          uri = uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              'emailAccountId': activeMailbox.value!.id,
            },
          );
        }
      }
      final request = http.Request(method, uri);
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
      final response = await sendApiRequest(
        _client,
        request,
        timeout: requestTimeout,
        cancellation: cancellation,
      );
      if (cancellation?.isCancelled == true) return null;
      if (authenticated &&
          (generation != _identityGeneration ||
              revision != mailboxRevision.value)) {
        return null;
      }
      if (response.statusCode == 401 && authenticated && allowStepUp) {
        // Decide authentication flow from the service response, independently
        // of the user-facing wording produced by the error formatter.
        if (isRecentAuthenticationRequired(
          _serverMessageFromResponse(response),
        )) {
          _lastError = _errorMessageFromResponse(response);
          if (await reauthenticate()) {
            return _requestJson(
              method,
              path,
              body: body,
              authenticated: true,
              allowRefresh: allowRefresh,
              allowStepUp: false,
              idempotencyKey: idempotencyKey,
              cancellation: cancellation,
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
          cancellation: cancellation,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = _errorMessageFromResponse(response);
        return null;
      }
      if (response.body.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on SenderWhoRequestException catch (error) {
      _lastError = error.message;
      return null;
    } on http.RequestAbortedException {
      return null;
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
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _refreshToken;
    final generation = _identityGeneration;
    if (refreshToken == null) return false;
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/auth/refresh'));
      request.headers['Content-Type'] = 'application/json';
      final deviceId = await _ensureDeviceId();
      request.headers['X-SenderWho-Device-Id'] = deviceId;
      request.headers['X-SenderWho-Device-Name'] = _deviceName();
      request.body = jsonEncode({'refreshToken': refreshToken});
      final response = await sendApiRequest(
        _client,
        request,
        timeout: requestTimeout,
      );
      if (generation != _identityGeneration || refreshToken != _refreshToken) {
        return false;
      }
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

  Future<bool> _acceptSession(
    Map<String, dynamic> json, {
    String? provider,
    int? oauthAttempt,
  }) async {
    final generation = _identityGeneration;
    final accessToken = json['accessToken'] as String?;
    final refreshToken = json['refreshToken'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    if (accessToken == null || refreshToken == null) return false;

    try {
      // Persist first so the repository never reports an authenticated session
      // that cannot survive an app restart.
      final write = _sessionWrite.catchError((Object _) {}).then((_) async {
        if (generation != _identityGeneration ||
            (oauthAttempt != null && oauthAttempt != _oauthAttempt)) {
          return;
        }
        await _sessionStore.writeRefreshToken(refreshToken);
      });
      _sessionWrite = write;
      await write;
    } on Object catch (error) {
      debugPrint('Could not save the secure session: $error');
      _lastError = 'The secure session could not be saved on this device.';
      return false;
    }

    if (generation != _identityGeneration ||
        (oauthAttempt != null && oauthAttempt != _oauthAttempt)) {
      return false;
    }

    final changedIdentity = _userEmail != null && user?['email'] != _userEmail;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final emailFromSession = user?['email'] as String?;
    if (emailFromSession != null && emailFromSession != _userEmail) {
      _identityGeneration++;
      _profileInFlight = null;
      _accountsInFlight = null;
      _mailboxContextLoaded = false;
      userProfile.value = null;
      connectedAccounts.value = const [];
      activeMailbox.value = null;
    }
    _userEmail = emailFromSession ?? _userEmail;
    if (user != null &&
        (user['avatarUrl'] != null || user['displayName'] != null)) {
      userProfile.value = UserProfile.fromJson(user);
    }
    final email = _userEmail;
    if (email != null && email.isNotEmpty) {
      try {
        await _sessionStore.writeRememberedEmail(email);
        final normalizedProvider = provider?.trim().toLowerCase();
        if (normalizedProvider == 'google' ||
            normalizedProvider == 'microsoft' ||
            normalizedProvider == 'yahoo') {
          await _sessionStore.writeRememberedProvider(normalizedProvider!);
        }
      } on Object catch (error) {
        debugPrint('Could not remember the account identity: $error');
      }
    }
    authenticationState.value = true;
    if (changedIdentity) mailboxRevision.value++;
    return true;
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _userEmail = null;
    _identityGeneration++;
    _profileInFlight = null;
    _accountsInFlight = null;
    _mailboxContextLoaded = false;
    _mailboxSwitchInFlight = null;
    switchingMailbox.value = null;
    userProfile.value = null;
    connectedAccounts.value = const [];
    activeMailbox.value = null;
    authenticationState.value = false;
    try {
      final clear = _sessionWrite
          .catchError((Object _) {})
          .then((_) => _sessionStore.clear());
      _sessionWrite = clear;
      await clear;
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

String? _serverMessageFromResponse(http.Response response) {
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
  return serverMessage;
}

String _errorMessageFromResponse(http.Response response) {
  return friendlyHttpErrorMessage(
    response.statusCode,
    serverMessage: _serverMessageFromResponse(response),
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
