import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/user_friendly_error.dart';

Color appColorFromKey(String? key) {
  switch (key) {
    case 'danger':
      return AppColors.danger;
    case 'indigo':
      return AppColors.indigo;
    case 'orange':
      return AppColors.orange;
    case 'success':
      return AppColors.success;
    case 'warning':
      return AppColors.warning;
    case 'text':
      return AppColors.text;
    case 'primary':
    default:
      return AppColors.primary;
  }
}

IconData categoryIconFromKey(String? key) {
  switch (key) {
    case 'account_balance':
      return Icons.account_balance_outlined;
    case 'flight':
      return Icons.flight_takeoff_rounded;
    case 'newspaper':
      return Icons.newspaper_rounded;
    case 'person':
      return Icons.person_outline_rounded;
    case 'report':
      return Icons.report_gmailerrorred_rounded;
    case 'sell':
      return Icons.sell_outlined;
    case 'shopping_bag':
      return Icons.shopping_bag_outlined;
    case 'star':
    default:
      return Icons.star_border_rounded;
  }
}

class SenderInfo {
  const SenderInfo({
    this.id = '',
    required this.name,
    required this.email,
    required this.category,
    required this.score,
    required this.initial,
    required this.color,
    this.totalMessages = 0,
    this.unreadMessages = 0,
    this.isBlocked = false,
    this.isTrusted = false,
    this.identityStatus = 'UNVERIFIED',
    this.identityRiskLevel = 'LOW',
    this.identityRiskScore = 0,
  });

  final String id;
  final String name;
  final String email;
  final String category;
  final int score;
  final String initial;
  final Color color;
  final int totalMessages;
  final int unreadMessages;
  final bool isBlocked;
  final bool isTrusted;
  final String identityStatus;
  final String identityRiskLevel;
  final int identityRiskScore;

  factory SenderInfo.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    final email = (json['email'] as String?)?.trim() ?? '';
    final displayName = name?.isNotEmpty == true ? name! : email;

    return SenderInfo(
      id: (json['id'] as String?) ?? '',
      name: displayName,
      email: email,
      category: (json['category'] as String?) ?? 'Unknown',
      score: (json['score'] as num?)?.round() ?? 0,
      initial:
          (json['initial'] as String?) ??
          (displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
      color: appColorFromKey(json['colorKey'] as String?),
      totalMessages: (json['totalMessages'] as num?)?.round() ?? 0,
      unreadMessages: (json['unreadMessages'] as num?)?.round() ?? 0,
      isBlocked: (json['isBlocked'] as bool?) ?? false,
      isTrusted: (json['isTrusted'] as bool?) ?? false,
      identityStatus:
          (json['identityStatus'] as String?)?.toUpperCase() ?? 'UNVERIFIED',
      identityRiskLevel:
          (json['identityRiskLevel'] as String?)?.toUpperCase() ?? 'LOW',
      identityRiskScore: (json['identityRiskScore'] as num?)?.round() ?? 0,
    );
  }
}

class SenderPage {
  const SenderPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<SenderInfo> items;
  final int total;
  final int page;
  final int limit;
  bool get hasMore => page * limit < total;

  factory SenderPage.fromJson(Map<String, dynamic> json) {
    return SenderPage(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => SenderInfo.fromJson(item.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.round() ?? 0,
      page: (json['page'] as num?)?.round() ?? 1,
      limit: (json['limit'] as num?)?.round() ?? 25,
    );
  }
}

class SenderDetails {
  const SenderDetails({
    required this.sender,
    required this.messages,
    required this.firstSeen,
    required this.location,
    required this.type,
  });

  final SenderInfo sender;
  final List<EmailItem> messages;
  final String firstSeen;
  final String location;
  final String type;

  factory SenderDetails.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => EmailItem.fromJson(item.cast<String, dynamic>()))
        .toList();

    return SenderDetails(
      sender: SenderInfo.fromJson(json),
      messages: messages,
      firstSeen: (json['firstSeenAt'] as String?) ?? 'Not available',
      location: (json['location'] as String?) ?? 'Unknown',
      type:
          (json['type'] as String?) ??
          (json['category'] as String? ?? 'Unknown'),
    );
  }
}

class AlertItem {
  const AlertItem({
    this.id = '',
    this.senderId = '',
    this.messageId = '',
    this.status = 'OPEN',
    required this.title,
    required this.email,
    required this.reason,
    required this.time,
    required this.risk,
    required this.color,
    this.identityRiskScore = 0,
    this.identityRiskLevel = 'LOW',
    this.identityStatus = 'UNVERIFIED',
    this.identityEvidence = const [],
    this.claimedBrand,
    this.authenticatedDomain,
    this.replyToEmail,
  });

  final String id;
  final String senderId;
  final String messageId;
  final String status;
  final String title;
  final String email;
  final String reason;
  final String time;
  final String risk;
  final Color color;
  final int identityRiskScore;
  final String identityRiskLevel;
  final String identityStatus;
  final List<IdentityEvidence> identityEvidence;
  final String? claimedBrand;
  final String? authenticatedDomain;
  final String? replyToEmail;

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: (json['id'] as String?) ?? '',
      senderId: (json['senderId'] as String?) ?? '',
      messageId: (json['messageId'] as String?) ?? '',
      status: ((json['status'] as String?) ?? 'OPEN').toUpperCase(),
      title: (json['title'] as String?) ?? 'Security Alert',
      email: (json['email'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      time: (json['time'] as String?) ?? '',
      risk: (json['risk'] as String?) ?? 'Risk',
      color: appColorFromKey(json['colorKey'] as String?),
      identityRiskScore: (json['identityRiskScore'] as num?)?.round() ?? 0,
      identityRiskLevel:
          (json['identityRiskLevel'] as String?)?.toUpperCase() ?? 'LOW',
      identityStatus:
          (json['identityStatus'] as String?)?.toUpperCase() ?? 'UNVERIFIED',
      identityEvidence: (json['identityEvidence'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => IdentityEvidence.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      claimedBrand: json['claimedBrand'] as String?,
      authenticatedDomain: json['authenticatedDomain'] as String?,
      replyToEmail: json['replyToEmail'] as String?,
    );
  }
}

class IdentityEvidence {
  const IdentityEvidence({
    required this.code,
    required this.detail,
    required this.weight,
  });

  final String code;
  final String detail;
  final int weight;

  factory IdentityEvidence.fromJson(Map<String, dynamic> json) {
    return IdentityEvidence(
      code: (json['code'] as String?) ?? 'IDENTITY_REVIEW',
      detail: (json['detail'] as String?) ?? 'Sender identity needs review.',
      weight: (json['weight'] as num?)?.round() ?? 0,
    );
  }
}

class SecurityAlertPage {
  const SecurityAlertPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  final List<AlertItem> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  factory SecurityAlertPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => AlertItem.fromJson(item.cast<String, dynamic>()))
        .toList();
    final page = (json['page'] as num?)?.round() ?? 1;
    final limit = (json['limit'] as num?)?.round() ?? 25;
    final total = (json['total'] as num?)?.round() ?? items.length;
    return SecurityAlertPage(
      items: items,
      total: total,
      page: page,
      limit: limit,
      hasMore: (json['hasMore'] as bool?) ?? page * limit < total,
    );
  }
}

class InboxHealthBreakdown {
  const InboxHealthBreakdown({
    required this.key,
    required this.label,
    required this.score,
    required this.body,
    required this.color,
    required this.icon,
    required this.available,
  });

  final String key;
  final String label;
  final int score;
  final String body;
  final Color color;
  final IconData icon;
  final bool available;

  factory InboxHealthBreakdown.fromJson(Map<String, dynamic> json) {
    final key = (json['key'] as String?) ?? '';
    final score = (json['score'] as num?)?.round() ?? 0;
    return InboxHealthBreakdown(
      key: key,
      label: (json['label'] as String?) ?? 'Health',
      score: score,
      body: (json['body'] as String?) ?? _healthBodyFor(key),
      color: score >= 80
          ? AppColors.success
          : score >= 70
          ? AppColors.warning
          : AppColors.danger,
      icon: _healthIconFor(key),
      available: (json['available'] as bool?) ?? true,
    );
  }
}

class InboxHealthSummary {
  const InboxHealthSummary({
    required this.score,
    required this.status,
    required this.breakdown,
  });

  final int score;
  final String status;
  final List<InboxHealthBreakdown> breakdown;

  factory InboxHealthSummary.fromJson(Map<String, dynamic> json) {
    return InboxHealthSummary(
      score: (json['score'] as num?)?.round() ?? 0,
      status: (json['status'] as String?) ?? 'Waiting for scan',
      breakdown: (json['breakdown'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                InboxHealthBreakdown.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class ConnectedEmailAccount {
  const ConnectedEmailAccount({
    required this.id,
    required this.provider,
    required this.emailAddress,
    required this.displayName,
    required this.syncStatus,
    this.recoveryAction = 'NONE',
    this.lastSyncedAt,
    this.lastSyncError,
    this.syncStartedAt,
    this.backfillComplete = false,
    this.backfillProcessed = 0,
  });

  final String id;
  final String provider;
  final String emailAddress;
  final String displayName;
  final String syncStatus;
  final String recoveryAction;
  final DateTime? lastSyncedAt;
  final String? lastSyncError;
  final DateTime? syncStartedAt;
  final bool backfillComplete;
  final int backfillProcessed;

  factory ConnectedEmailAccount.fromJson(Map<String, dynamic> json) {
    final provider = (json['provider'] as String?) ?? 'GOOGLE';
    return ConnectedEmailAccount(
      id: (json['id'] as String?) ?? '',
      provider: provider,
      emailAddress: (json['emailAddress'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? provider,
      syncStatus: (json['syncStatus'] as String?) ?? 'PENDING',
      recoveryAction: (json['recoveryAction'] as String?) ?? 'NONE',
      lastSyncedAt: DateTime.tryParse((json['lastSyncedAt'] as String?) ?? ''),
      lastSyncError: switch (json['lastSyncError']) {
        final String message when message.trim().isNotEmpty =>
          sanitizeUserMessage(
            message,
            fallback:
                'Email syncing needs attention. Reconnect the account or try again.',
          ),
        _ => null,
      },
      syncStartedAt: DateTime.tryParse(
        (json['syncStartedAt'] as String?) ?? '',
      ),
      backfillComplete: (json['backfillComplete'] as bool?) ?? false,
      backfillProcessed: (json['backfillProcessed'] as num?)?.round() ?? 0,
    );
  }
}

class DisconnectAccountResult {
  const DisconnectAccountResult({
    required this.disconnected,
    required this.providerRevoked,
  });

  final bool disconnected;
  final bool providerRevoked;

  factory DisconnectAccountResult.fromJson(Map<String, dynamic> json) {
    return DisconnectAccountResult(
      disconnected:
          (json['syncStatus'] as String?) == 'DISCONNECTED' ||
          json['disconnected'] == true ||
          json.isNotEmpty,
      providerRevoked: json['providerRevoked'] == true,
    );
  }
}

class CleanupSuggestion {
  const CleanupSuggestion({
    required this.id,
    required this.emailAccountId,
    required this.categoryKey,
    required this.category,
    required this.messageCount,
    required this.estimatedSpaceBytes,
  });

  final String id;
  final String emailAccountId;
  final String categoryKey;
  final String category;
  final int messageCount;
  final int estimatedSpaceBytes;

  factory CleanupSuggestion.fromJson(Map<String, dynamic> json) {
    return CleanupSuggestion(
      id: (json['id'] as String?) ?? '',
      emailAccountId: (json['emailAccountId'] as String?) ?? '',
      categoryKey:
          (json['categoryKey'] as String?) ??
          (json['category'] as String?) ??
          '',
      category: (json['category'] as String?) ?? 'Emails',
      messageCount: (json['messageCount'] as num?)?.round() ?? 0,
      estimatedSpaceBytes: (json['estimatedSpaceBytes'] as num?)?.round() ?? 0,
    );
  }
}

class CleanupJobInfo {
  const CleanupJobInfo({
    required this.id,
    required this.status,
    required this.totalMessages,
    required this.processedMessages,
    required this.failedMessages,
  });

  final String id;
  final String status;
  final int totalMessages;
  final int processedMessages;
  final int failedMessages;

  bool get isFinished =>
      status == 'COMPLETED' || status == 'FAILED' || status == 'CANCELED';

  factory CleanupJobInfo.fromJson(Map<String, dynamic> json) {
    return CleanupJobInfo(
      id: (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'QUEUED',
      totalMessages: (json['totalMessages'] as num?)?.round() ?? 0,
      processedMessages: (json['processedMessages'] as num?)?.round() ?? 0,
      failedMessages: (json['failedMessages'] as num?)?.round() ?? 0,
    );
  }
}

class CleanupPreview {
  const CleanupPreview({
    required this.previewId,
    required this.emailAccountId,
    required this.categories,
    required this.totalMessages,
    required this.estimatedSpaceBytes,
  });

  final String previewId;
  final String emailAccountId;
  final List<String> categories;
  final int totalMessages;
  final int estimatedSpaceBytes;

  factory CleanupPreview.fromJson(Map<String, dynamic> json) {
    return CleanupPreview(
      previewId: (json['previewId'] as String?) ?? '',
      emailAccountId: (json['emailAccountId'] as String?) ?? '',
      categories: (json['categories'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      totalMessages: (json['totalMessages'] as num?)?.round() ?? 0,
      estimatedSpaceBytes: (json['estimatedSpaceBytes'] as num?)?.round() ?? 0,
    );
  }
}

class UnsubscribeCandidate {
  const UnsubscribeCandidate({
    required this.id,
    required this.name,
    required this.email,
    required this.reason,
    required this.color,
  });

  final String id;
  final String name;
  final String email;
  final String reason;
  final Color color;

  factory UnsubscribeCandidate.fromJson(Map<String, dynamic> json) {
    return UnsubscribeCandidate(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Sender',
      email: (json['email'] as String?) ?? '',
      reason: sanitizeUserMessage(
        json['reason'] as String?,
        fallback: 'This message could not be updated. Please try again.',
      ),
      color: appColorFromKey(json['colorKey'] as String?),
    );
  }
}

class UnsubscribeJobInfo {
  const UnsubscribeJobInfo({
    required this.id,
    required this.status,
    this.senderId = '',
    this.failureReason = '',
  });

  final String id;
  final String status;
  final String senderId;
  final String failureReason;
  bool get isActive => status == 'QUEUED' || status == 'RUNNING';
  bool get isFinished =>
      status == 'COMPLETED' || status == 'FAILED' || status == 'CANCELED';

  factory UnsubscribeJobInfo.fromJson(Map<String, dynamic> json) {
    return UnsubscribeJobInfo(
      id: (json['id'] as String?) ?? '',
      status: ((json['status'] as String?) ?? 'QUEUED').toUpperCase(),
      senderId: (json['senderId'] as String?) ?? '',
      failureReason: _safeUnsubscribeFailureReason(
        json['failureReason'] ?? json['reason'],
      ),
    );
  }
}

class UnsubscribeBatchFailure {
  const UnsubscribeBatchFailure({required this.senderId, required this.reason});

  final String senderId;
  final String reason;

  factory UnsubscribeBatchFailure.fromJson(Map<String, dynamic> json) {
    return UnsubscribeBatchFailure(
      senderId: (json['senderId'] as String?) ?? '',
      reason: _safeUnsubscribeFailureReason(json['reason']),
    );
  }
}

class UnsubscribeBatchResult {
  const UnsubscribeBatchResult({required this.jobs, required this.failures});

  final List<UnsubscribeJobInfo> jobs;
  final List<UnsubscribeBatchFailure> failures;

  factory UnsubscribeBatchResult.fromJson(Map<String, dynamic> json) {
    return UnsubscribeBatchResult(
      jobs: (json['jobs'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => UnsubscribeJobInfo.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      failures: (json['failures'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                UnsubscribeBatchFailure.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

String _safeUnsubscribeFailureReason(Object? value) {
  if (value is! String) return '';
  final normalized = value
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.length <= 180) return normalized;
  return '${normalized.substring(0, 177)}...';
}

class TopSenderItem {
  const TopSenderItem({
    this.id = '',
    required this.rank,
    required this.name,
    required this.email,
    required this.count,
  });

  final String id;
  final int rank;
  final String name;
  final String email;
  final int count;

  factory TopSenderItem.fromJson(Map<String, dynamic> json) {
    return TopSenderItem(
      id: (json['id'] as String?) ?? '',
      rank: (json['rank'] as num?)?.round() ?? 0,
      name: (json['name'] as String?) ?? 'Sender',
      email: (json['email'] as String?) ?? '',
      count: (json['count'] as num?)?.round() ?? 0,
    );
  }
}

class ActivityStat {
  const ActivityStat({
    required this.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final String key;
  final String value;
  final String label;
  final Color color;

  factory ActivityStat.fromJson(Map<String, dynamic> json) {
    return ActivityStat(
      key: (json['key'] as String?) ?? '',
      value: '${json['value'] ?? ''}',
      label: (json['label'] as String?) ?? '',
      color: appColorFromKey(json['colorKey'] as String?),
    );
  }
}

class WeeklyActivityPoint {
  const WeeklyActivityPoint({required this.day, required this.value});

  final String day;
  final double value;

  factory WeeklyActivityPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyActivityPoint(
      day: (json['day'] as String?) ?? '',
      value: (json['value'] as num?)?.toDouble().clamp(0, 1) ?? 0,
    );
  }
}

class ActivityInsights {
  const ActivityInsights({
    required this.period,
    required this.stats,
    required this.weeklyActivity,
  });

  final String period;
  final List<ActivityStat> stats;
  final List<WeeklyActivityPoint> weeklyActivity;

  factory ActivityInsights.fromJson(Map<String, dynamic> json) {
    return ActivityInsights(
      period: (json['period'] as String?) ?? 'Unavailable',
      stats: (json['stats'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ActivityStat.fromJson(item.cast<String, dynamic>()))
          .toList(),
      weeklyActivity: (json['weeklyActivity'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                WeeklyActivityPoint.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class SearchFilterOptions {
  const SearchFilterOptions({
    required this.categories,
    required this.trustScores,
    required this.dateRanges,
  });

  final List<String> categories;
  final List<String> trustScores;
  final List<String> dateRanges;

  factory SearchFilterOptions.fromJson(Map<String, dynamic> json) {
    return SearchFilterOptions(
      categories: _stringListFrom(json['categories']),
      trustScores: _stringListFrom(json['trustScores']),
      dateRanges: _stringListFrom(json['dateRanges']),
    );
  }
}

class SearchResults {
  const SearchResults({
    required this.total,
    required this.senders,
    required this.emails,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  final int total;
  final List<SenderInfo> senders;
  final List<EmailItem> emails;
  final int page;
  final int limit;
  final bool hasMore;
  int get returned => senders.length + emails.length;

  SearchResults append(SearchResults next) {
    final senderIds = senders.map((item) => item.id).toSet();
    final emailIds = emails.map((item) => item.id).toSet();
    return SearchResults(
      total: next.total,
      senders: [
        ...senders,
        ...next.senders.where((item) => senderIds.add(item.id)),
      ],
      emails: [
        ...emails,
        ...next.emails.where((item) => emailIds.add(item.id)),
      ],
      page: next.page,
      limit: next.limit,
      hasMore: next.hasMore,
    );
  }

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    return SearchResults(
      total: (json['total'] as num?)?.round() ?? 0,
      senders: (json['senders'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => SenderInfo.fromJson(item.cast<String, dynamic>()))
          .toList(),
      emails: (json['emails'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => EmailItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      page: (json['page'] as num?)?.round() ?? 1,
      limit: (json['limit'] as num?)?.round() ?? 25,
      hasMore: (json['hasMore'] as bool?) ?? false,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.connectedAccountsCount,
    required this.notificationsEnabled,
    required this.inboxScanFrequency,
    required this.theme,
    required this.archivedEmails,
    required this.trashEmails,
    required this.blockedSenders,
  });

  final int connectedAccountsCount;
  final bool notificationsEnabled;
  final String inboxScanFrequency;
  final String theme;
  final int archivedEmails;
  final int trashEmails;
  final int blockedSenders;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final account = json['account'] as Map<String, dynamic>? ?? {};
    final preferences = json['preferences'] as Map<String, dynamic>? ?? {};
    final emailManagement =
        json['emailManagement'] as Map<String, dynamic>? ?? {};

    return AppSettings(
      connectedAccountsCount:
          (account['connectedAccountsCount'] as num?)?.round() ?? 0,
      notificationsEnabled:
          (preferences['notificationsEnabled'] as bool?) ?? true,
      inboxScanFrequency:
          (preferences['inboxScanFrequency'] as String?) ?? 'Auto',
      theme: (preferences['theme'] as String?) ?? 'System',
      archivedEmails: (emailManagement['archivedEmails'] as num?)?.round() ?? 0,
      trashEmails: (emailManagement['trashEmails'] as num?)?.round() ?? 0,
      blockedSenders: (emailManagement['blockedSenders'] as num?)?.round() ?? 0,
    );
  }
}

class PrivacySecuritySummary {
  const PrivacySecuritySummary({
    required this.twoFactorEnabled,
    required this.blockedSenders,
    required this.trustedSenders,
    required this.dataRetention,
    required this.privacyMode,
  });

  final bool twoFactorEnabled;
  final int blockedSenders;
  final int trustedSenders;
  final String dataRetention;
  final String privacyMode;

  factory PrivacySecuritySummary.fromJson(Map<String, dynamic> json) {
    return PrivacySecuritySummary(
      twoFactorEnabled: (json['twoFactorEnabled'] as bool?) ?? false,
      blockedSenders: (json['blockedSenders'] as num?)?.round() ?? 0,
      trustedSenders: (json['trustedSenders'] as num?)?.round() ?? 0,
      dataRetention: (json['dataRetention'] as String?) ?? 'Metadata only',
      privacyMode: (json['privacyMode'] as String?) ?? 'Standard',
    );
  }
}

String _healthBodyFor(String key) {
  switch (key) {
    case 'senderTrust':
      return 'Most senders contacting you are verified and trustworthy.';
    case 'spamProtection':
      return 'Some suspicious emails are bypassing filters. Review recommended.';
    case 'inboxClutter':
      return 'Your inbox has accumulated newsletters and promotional emails over time.';
    default:
      return 'Review this inbox health signal for more details.';
  }
}

IconData _healthIconFor(String key) {
  switch (key) {
    case 'senderTrust':
      return Icons.verified_user_outlined;
    case 'spamProtection':
      return Icons.report_gmailerrorred_outlined;
    case 'inboxClutter':
      return Icons.inbox_outlined;
    default:
      return Icons.health_and_safety_outlined;
  }
}

class EmailItem {
  const EmailItem({
    this.id = '',
    this.senderId,
    this.threadId,
    required this.sender,
    required this.email,
    required this.subject,
    required this.date,
    this.snippet = '',
    this.category = 'UNKNOWN',
    this.isRead = false,
    this.isArchived = false,
    this.isTrashed = false,
    this.hasAttachments = false,
    this.sizeBytes,
    this.canUnsubscribe = false,
    this.accountEmail = '',
    this.identityRiskScore = 0,
    this.identityRiskLevel = 'LOW',
    this.identityStatus = 'UNVERIFIED',
    this.identityEvidence = const [],
    this.claimedBrand,
    this.authenticatedDomain,
    this.replyToEmail,
  });

  final String id;
  final String? senderId;
  final String? threadId;
  final String sender;
  final String email;
  final String subject;
  final String date;
  final String snippet;
  final String category;
  final bool isRead;
  final bool isArchived;
  final bool isTrashed;
  final bool hasAttachments;
  final int? sizeBytes;
  final bool canUnsubscribe;
  final String accountEmail;
  final int identityRiskScore;
  final String identityRiskLevel;
  final String identityStatus;
  final List<IdentityEvidence> identityEvidence;
  final String? claimedBrand;
  final String? authenticatedDomain;
  final String? replyToEmail;

  factory EmailItem.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] as String?) ?? '';
    return EmailItem(
      id: (json['id'] as String?) ?? '',
      senderId: json['senderId'] as String?,
      threadId: json['threadId'] as String?,
      sender: (json['sender'] as String?) ?? 'Unknown',
      email: (json['email'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? '(No subject)',
      date: _formatEmailDate(rawDate),
      snippet: (json['snippet'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'UNKNOWN',
      isRead: (json['isRead'] as bool?) ?? false,
      isArchived: (json['isArchived'] as bool?) ?? false,
      isTrashed: (json['isTrashed'] as bool?) ?? false,
      hasAttachments: (json['hasAttachments'] as bool?) ?? false,
      sizeBytes: (json['sizeBytes'] as num?)?.round(),
      canUnsubscribe: (json['canUnsubscribe'] as bool?) ?? false,
      accountEmail: (json['accountEmail'] as String?) ?? '',
      identityRiskScore: (json['identityRiskScore'] as num?)?.round() ?? 0,
      identityRiskLevel:
          (json['identityRiskLevel'] as String?)?.toUpperCase() ?? 'LOW',
      identityStatus:
          (json['identityStatus'] as String?)?.toUpperCase() ?? 'UNVERIFIED',
      identityEvidence: (json['identityEvidence'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => IdentityEvidence.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      claimedBrand: json['claimedBrand'] as String?,
      authenticatedDomain: json['authenticatedDomain'] as String?,
      replyToEmail: json['replyToEmail'] as String?,
    );
  }
}

class EmailThread {
  const EmailThread({
    required this.threadId,
    required this.total,
    required this.items,
  });

  final String? threadId;
  final int total;
  final List<EmailItem> items;

  factory EmailThread.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => EmailItem.fromJson(item.cast<String, dynamic>()))
        .toList();
    return EmailThread(
      threadId: json['threadId'] as String?,
      total: (json['total'] as num?)?.round() ?? items.length,
      items: items,
    );
  }
}

class EmailAttachment {
  const EmailAttachment({required this.filename, required this.sizeBytes});

  final String filename;
  final int sizeBytes;

  factory EmailAttachment.fromJson(Map<String, dynamic> json) {
    return EmailAttachment(
      filename: (json['filename'] as String?) ?? 'Attachment',
      sizeBytes: (json['sizeBytes'] as num?)?.round() ?? 0,
    );
  }
}

class EmailContent {
  const EmailContent({
    required this.id,
    required this.from,
    required this.to,
    required this.cc,
    required this.subject,
    required this.date,
    required this.bodyText,
    required this.truncated,
    required this.attachments,
  });

  final String id;
  final String from;
  final String to;
  final String cc;
  final String subject;
  final String date;
  final String bodyText;
  final bool truncated;
  final List<EmailAttachment> attachments;

  factory EmailContent.fromJson(Map<String, dynamic> json) {
    return EmailContent(
      id: (json['id'] as String?) ?? '',
      from: (json['from'] as String?) ?? '',
      to: (json['to'] as String?) ?? '',
      cc: (json['cc'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? '(No subject)',
      date: (json['date'] as String?) ?? '',
      bodyText: (json['bodyText'] as String?) ?? '',
      truncated: (json['truncated'] as bool?) ?? false,
      attachments: (json['attachments'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => EmailAttachment.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class EmailPage {
  const EmailPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  final List<EmailItem> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  factory EmailPage.fromJson(Map<String, dynamic> json) {
    return EmailPage(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => EmailItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.round() ?? 0,
      page: (json['page'] as num?)?.round() ?? 1,
      limit: (json['limit'] as num?)?.round() ?? 25,
      hasMore: (json['hasMore'] as bool?) ?? false,
    );
  }
}

class MessageActionFailure {
  const MessageActionFailure({required this.messageId, required this.reason});

  final String messageId;
  final String reason;

  factory MessageActionFailure.fromJson(Map<String, dynamic> json) {
    return MessageActionFailure(
      messageId: (json['messageId'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
    );
  }
}

class MessageActionResult {
  const MessageActionResult({
    required this.action,
    required this.requested,
    required this.processed,
    required this.failed,
    this.processedIds = const [],
    this.failures = const [],
  });

  final String action;
  final int requested;
  final int processed;
  final int failed;
  final List<String> processedIds;
  final List<MessageActionFailure> failures;
  bool get succeeded => requested > 0 && failed == 0 && processed == requested;

  factory MessageActionResult.fromJson(Map<String, dynamic> json) {
    final processedIds = (json['processedIds'] as List? ?? const [])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final failures = (json['failures'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (failure) =>
              MessageActionFailure.fromJson(failure.cast<String, dynamic>()),
        )
        .where((failure) => failure.messageId.isNotEmpty)
        .toList(growable: false);
    return MessageActionResult(
      action: (json['action'] as String?) ?? '',
      requested:
          (json['requested'] as num?)?.round() ??
          processedIds.length + failures.length,
      processed: (json['processed'] as num?)?.round() ?? processedIds.length,
      failed: (json['failed'] as num?)?.round() ?? failures.length,
      processedIds: processedIds,
      failures: failures,
    );
  }
}

class AppSessionInfo {
  const AppSessionInfo({
    required this.id,
    required this.deviceName,
    required this.userAgent,
    required this.ipAddress,
    required this.current,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final String id;
  final String deviceName;
  final String userAgent;
  final String ipAddress;
  final bool current;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  factory AppSessionInfo.fromJson(Map<String, dynamic> json) {
    return AppSessionInfo(
      id: (json['id'] as String?) ?? '',
      deviceName: (json['deviceName'] as String?) ?? '',
      userAgent: (json['userAgent'] as String?) ?? '',
      ipAddress: (json['ipAddress'] as String?) ?? '',
      current: (json['current'] as bool?) ?? false,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
      lastUsedAt: DateTime.tryParse((json['lastUsedAt'] as String?) ?? ''),
    );
  }

  String get label {
    if (deviceName.isNotEmpty) return deviceName;
    if (userAgent.isNotEmpty) {
      return userAgent.length <= 55
          ? userAgent
          : '${userAgent.substring(0, 52)}…';
    }
    return 'Unknown device';
  }
}

String _formatEmailDate(String source) {
  final parsed = DateTime.tryParse(source)?.toLocal();
  if (parsed == null) return source;
  final now = DateTime.now();
  if (parsed.year == now.year &&
      parsed.month == now.month &&
      parsed.day == now.day) {
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}

class CategoryItem {
  const CategoryItem({
    this.id = '',
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String count;
  final IconData icon;
  final Color color;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id:
          (json['id'] as String?) ??
          ((json['title'] as String?) ?? 'unknown').toUpperCase().replaceAll(
            ' ',
            '_',
          ),
      title: (json['title'] as String?) ?? 'Category',
      count: '${json['count'] ?? 0}',
      icon: categoryIconFromKey(json['iconKey'] as String?),
      color: appColorFromKey(json['colorKey'] as String?),
    );
  }
}

class NavItem {
  const NavItem({required this.title, required this.icon, required this.route});

  final String title;
  final IconData icon;
  final String route;
}

List<String> _stringListFrom(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => '$item').toList();
}
