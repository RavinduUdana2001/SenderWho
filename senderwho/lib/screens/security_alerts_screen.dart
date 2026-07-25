import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/alert_details_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';

class SecurityAlertsScreen extends StatefulWidget {
  const SecurityAlertsScreen({super.key, this.repository});

  static const routeName = '/security-alerts';
  final SenderWhoRepository? repository;

  @override
  State<SecurityAlertsScreen> createState() => _SecurityAlertsScreenState();
}

class _SecurityAlertsScreenState extends State<SecurityAlertsScreen> {
  final List<AlertItem> _alerts = [];
  String _risk = 'ALL';
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _inlineError;
  int _page = 0;
  int _total = 0;
  bool _hasMore = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore || (!reset && _loading)) return;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
      _inlineError = null;
    });
    try {
      final result = await _repository.getSecurityAlertsPage(
        page: reset ? 1 : _page + 1,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _alerts.clear();
        _alerts.addAll(result.items);
        _page = result.page;
        _total = result.total;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
        _inlineError = null;
      });
    } on Object catch (caught) {
      if (!mounted) return;
      final message = caught is SenderWhoRequestException
          ? caught.message
          : _repository.lastError ?? 'Could not load security alerts.';
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (_alerts.isEmpty) {
          _error = message;
        } else {
          _inlineError = message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleAlerts = _alerts.where((alert) {
      if (_risk == 'HIGH') return alert.risk.toUpperCase().contains('HIGH');
      if (_risk == 'MEDIUM') {
        return alert.risk.toUpperCase().contains('MEDIUM');
      }
      return true;
    }).toList();
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader(
            title: 'Security Alerts',
            subtitle: 'Review suspicious senders and identity risks',
            action: IconButton.filledTonal(
              tooltip: 'Refresh alerts',
              onPressed: _loading ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
          SizedBox(height: context.gap(18)),
          AppCard(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                const IconBubble(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_total alerts need review',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review risky senders before opening email links.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.gap(16)),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.trackFor(context),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                _RiskTab(
                  label: 'All',
                  selected: _risk == 'ALL',
                  onTap: () => setState(() => _risk = 'ALL'),
                ),
                _RiskTab(
                  label: 'High Risk',
                  selected: _risk == 'HIGH',
                  onTap: () => setState(() => _risk = 'HIGH'),
                ),
                _RiskTab(
                  label: 'Medium',
                  selected: _risk == 'MEDIUM',
                  onTap: () => setState(() => _risk = 'MEDIUM'),
                ),
              ],
            ),
          ),
          SizedBox(height: context.gap(16)),
          if (_loading && _alerts.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            AppAsyncError(message: _error!, onRetry: () => _load(reset: true))
          else if (visibleAlerts.isEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  IconBubble(
                    icon: Icons.security_rounded,
                    size: 54,
                    iconSize: 25,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'No alerts in this filter',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Your current Gmail metadata has no matching security risks.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            for (final alert in visibleAlerts) ...[
              SecurityAlertTile(
                alert: alert,
                onChanged: () => _load(reset: true),
              ),
              const SizedBox(height: 10),
            ],
          if (_inlineError != null) ...[
            AppAsyncError(
              title: 'Could not load more alerts',
              message: _inlineError!,
              onRetry: () => _load(reset: false),
            ),
            const SizedBox(height: 10),
          ],
          if (_hasMore)
            Center(
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _load(reset: false),
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_loadingMore ? 'Loading…' : 'Load more'),
              ),
            ),
        ],
      ),
    );
  }
}

class SecurityAlertTile extends StatelessWidget {
  const SecurityAlertTile({
    super.key,
    required this.alert,
    required this.onChanged,
  });

  final AlertItem alert;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () async {
        final changed = await Navigator.pushNamed<dynamic>(
          context,
          AlertDetailsScreen.routeName,
          arguments: alert,
        );
        if (changed == true) onChanged();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(
                icon: Icons.report_gmailerrorred_outlined,
                color: alert.color,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              StatusChip(label: alert.risk, color: alert.color),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  alert.reason,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Text(alert.time, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskTab extends StatelessWidget {
  const _RiskTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.surface(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : AppColors.mutedFor(context),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
