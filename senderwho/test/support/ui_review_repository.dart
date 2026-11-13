import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/services/senderwho_repository.dart';

class UiReviewData {
  final unhandled = <String>[];
  final batchRequests = <List<String>>[];
  final completed = <String>{};
  final bool failedRequest;
  bool failRefresh = false;
  UiReviewData({this.failedRequest = false});

  static const names = [
    'Canva',
    'LinkedIn',
    'Weekly product and design newsletter',
    'Amazon',
    'Figma',
    'Ravindu',
    'Travel updates',
    'Your local community',
  ];
  Map<String, Object?> sender(int i) => {
    'id': 'sender-$i',
    'name': names[i % names.length],
    'email': 'updates-${i + 1}@example.com',
    'category': i == 2 ? 'NEWSLETTERS' : 'PEOPLE',
    'score': 85,
    'totalMessages': 28 + i * 3,
    'unreadMessages': i.isEven ? 3 : 0,
    'identityStatus': i == 3 ? 'SUSPICIOUS' : 'VERIFIED',
    'identityRiskLevel': i == 3 ? 'HIGH' : 'LOW',
    'initial': names[i % names.length][0],
  };
  Map<String, Object?> message(int i) => {
    'id': 'message-$i',
    'senderId': 'sender-$i',
    'sender': names[i % names.length],
    'email': 'updates-${i + 1}@example.com',
    'subject': [
      'Your project update is ready',
      'A quick update for you',
      'This week in design',
    ][i % 3],
    'snippet': 'The latest news and updates, ready when you are.',
    'date': '2026-11-03T08:00:00Z',
    'isRead': true,
    'accountEmail': 'ravindu@example.com',
    'canUnsubscribe': true,
  };
  Map<String, Object?> candidate(int i) => {
    'id': 'sender-$i',
    'name': names[i % names.length],
    'email': 'updates-${i + 1}@example.com',
    'reason': 'Supports unsubscribe',
    'colorKey': 'primary',
  };
  Map<String, Object?> alert(int i) => {
    'id': 'alert-$i',
    'senderId': 'sender-$i',
    'messageId': 'message-$i',
    'title': i == 0
        ? 'Sender identity needs review'
        : 'Unexpected sign-in message',
    'email': 'security-${i + 1}@example.com',
    'reason': 'The sender could not be verified. Review before opening links.',
    'risk': i == 0 ? 'High Risk' : 'Medium Risk',
    'colorKey': i == 0 ? 'danger' : 'warning',
    'time': 'Today',
    'status': 'OPEN',
    'identityStatus': 'SUSPICIOUS',
    'identityRiskScore': 70,
    'identityEvidence': [],
  };
  Map<String, Object?> job(String senderId, String status) => {
    'id': 'job-$senderId',
    'senderId': senderId,
    'status': status,
    if (status == 'FAILED')
      'failureReason': 'The provider is temporarily unavailable. Try again.',
  };

  http.Response json(Object value, [int status = 200]) =>
      http.Response(jsonEncode(value), status);
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    if (path == 'dashboard') {
      return json({
        'inboxHealth': {'score': 86, 'status': 'Healthy inbox'},
        'metrics': {
          'totalMessages': 5003,
          'totalSenders': 285,
          'unreadEmails': 612,
          'newsletters': 290,
          'promotions': 342,
          'spam': 31,
        },
        'opportunities': {
          'cleanupMessages': 1248,
          'estimatedSpaceBytes': 734003200,
          'unsubscribeSenders': 47,
        },
        'topSenders': List.generate(
          3,
          (i) => {...sender(i), 'rank': i + 1, 'count': 240 - i * 20},
        ),
        'recentAlerts': List.generate(2, alert),
      });
    }
    if (path == 'inbox-health') {
      return json({
        'score': 86,
        'status': 'Healthy inbox',
        'breakdown': [
          {'key': 'senderTrust', 'label': 'Sender identity', 'score': 92},
          {'key': 'spamProtection', 'label': 'Spam protection', 'score': 75},
          {'key': 'inboxClutter', 'label': 'Inbox organization', 'score': 68},
        ],
      });
    }
    if (path == 'activity') {
      return json({
        'period': 'Last 7 days',
        'stats': [
          {'key': 'received', 'label': 'Emails received', 'value': '1,248'},
          {'key': 'read', 'label': 'Emails read', 'value': '986'},
          {'key': 'cleaned', 'label': 'Emails cleaned', 'value': '212'},
        ],
        'weeklyActivity': [
          for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
            {'day': day, 'value': .6},
        ],
      });
    }
    if (path == 'settings') {
      return json({
        'account': {'connectedAccountsCount': 2},
        'preferences': {
          'notificationsEnabled': true,
          'inboxScanFrequency': 'Auto',
          'theme': 'System',
        },
        'emailManagement': {
          'archivedEmails': 120,
          'trashEmails': 42,
          'blockedSenders': 3,
        },
      });
    }
    if (path == 'privacy-security') {
      return json({
        'twoFactorEnabled': false,
        'blockedSenders': 3,
        'trustedSenders': 12,
        'dataRetention': 'Metadata only',
        'privacyMode': 'Standard',
      });
    }
    if (path == 'auth/sessions') {
      return json({
        'items': [
          {
            'id': 'session-1',
            'deviceName': 'iPhone',
            'current': true,
            'lastUsedAt': '2026-11-03T08:00:00Z',
          },
          {
            'id': 'session-2',
            'deviceName': 'Chrome on Mac',
            'current': false,
            'lastUsedAt': '2026-11-02T08:00:00Z',
          },
        ],
      });
    }
    if (path == 'search/filters') {
      return json({
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
    if (path == 'senders') {
      return json({
        'items': List.generate(8, sender),
        'total': 8,
        'page': 1,
        'limit': 25,
      });
    }
    if (path == 'senders/top') {
      return json({
        'items': List.generate(
          8,
          (i) => {...sender(i), 'rank': i + 1, 'count': 240 - i * 20},
        ),
      });
    }
    if (path.startsWith('senders/')) {
      return json({
        ...sender(0),
        'messages': List.generate(6, message),
        'firstSeenAt': '2024-11-27T00:00:00Z',
        'type': 'COMPANY',
        'location': 'Not available',
      });
    }
    if (path == 'categories') {
      return json({
        'items': [
          for (final entry in {
            'PEOPLE': 'People',
            'PROMOTIONS': 'Offers',
            'NEWSLETTERS': 'Newsletters',
            'FINANCE': 'Finance',
            'TRAVEL': 'Travel',
          }.entries)
            {
              'id': entry.key,
              'title': entry.value,
              'count': '128',
              'colorKey': 'primary',
            },
        ],
      });
    }
    if (path == 'emails') {
      return json({
        'items': List.generate(8, message),
        'total': 8,
        'page': 1,
        'limit': 25,
        'hasMore': false,
      });
    }
    if (path.endsWith('/thread')) {
      return json({
        'items': [message(0)],
        'total': 1,
        'threadId': 'thread-1',
      });
    }
    if (path.endsWith('/content')) {
      return json({
        'id': 'message-0',
        'from': 'updates@example.com',
        'to': 'ravindu@example.com',
        'cc': '',
        'date': 'Today',
        'bodyText':
            'Hi Ravindu,\n\nYour latest project update is ready. We have included the changes from our last conversation.\n\nTake a look when you have a moment.\n\nThanks,\nThe team',
        'attachments': [],
      });
    }
    if (path.startsWith('emails/')) return json(message(0));
    if (path == 'security-alerts') {
      return json({
        'items': List.generate(2, alert),
        'total': 2,
        'page': 1,
        'limit': 25,
      });
    }
    if (path.startsWith('security-alerts/')) return json(alert(0));
    if (path == 'email-accounts') {
      return json({
        'items': [
          {
            'id': 'account-1',
            'provider': 'GOOGLE',
            'emailAddress': 'ravindu@gmail.com',
            'displayName': 'Personal Gmail',
            'isActive': true,
            'syncStatus': 'READY',
            'lastSyncedAt': '2026-11-03T08:00:00Z',
          },
          {
            'id': 'account-2',
            'provider': 'YAHOO',
            'emailAddress': 'ravindu@yahoo.com',
            'displayName': 'Yahoo Mail',
            'isActive': false,
            'syncStatus': 'READY',
            'lastSyncedAt': '2026-11-03T08:00:00Z',
          },
        ],
      });
    }
    if (path == 'auth/providers') {
      return json({
        'providers': {
          for (final provider in ['google', 'microsoft', 'yahoo'])
            provider: {'enabled': true},
        },
      });
    }
    if (path == 'auth/me') {
      return json({
        'email': 'ravindu@example.com',
        'displayName': 'Ravindu Singapura',
      });
    }
    if (path == 'cleanup/suggestions') {
      return json({
        'items': [
          for (var i = 0; i < 3; i++)
            {
              'id': 'cleanup-$i',
              'emailAccountId': 'account-1',
              'categoryKey': ['MARKETING', 'NEWSLETTERS', 'SPAM'][i],
              'category': ['Promotions', 'Newsletters', 'Spam'][i],
              'messageCount': 128,
              'estimatedSpaceBytes': 2097152,
            },
        ],
      });
    }
    if (path == 'cleanup/jobs') return json({'items': []});
    if (path == 'unsubscribe/candidates') {
      if (failRefresh) {
        return json({'message': 'Service temporarily unavailable'}, 503);
      }
      return json({
        'items': [
          for (var i = 0; i < 8; i++)
            if (!completed.contains('sender-$i')) candidate(i),
        ],
      });
    }
    if (path == 'unsubscribe/jobs' && request.method == 'GET') {
      return json({
        'items': failedRequest ? [job('sender-2', 'FAILED')] : [],
      });
    }
    if (path == 'unsubscribe/jobs/batch' && request.method == 'POST') {
      final ids = List<String>.from(
        (jsonDecode(request.body) as Map)['senderIds'] as List,
      );
      batchRequests.add(ids);
      completed.addAll(ids);
      return json({
        'jobs': [for (final id in ids) job(id, 'COMPLETED')],
        'failures': [],
      });
    }
    unhandled.add('${request.method} $path');
    return json({'message': 'Not found'}, 404);
  }

  SenderWhoRepository repository() {
    final repository = SenderWhoRepository(
      previewMode: false,
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient(handle),
    );
    repository.userProfile.value = const UserProfile(
      email: 'ravindu@example.com',
      displayName: 'Ravindu Singapura',
    );
    return repository;
  }
}
