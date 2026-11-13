import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Keeps a real back stack while reusing destinations already on that stack.
class AppNavigationObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];
  String lastMailboxRoute = '/all-senders';

  Route<dynamic>? find(String name) => _routes
      .where(
        (route) =>
            route.settings.name == name && route.settings.arguments == null,
      )
      .lastOrNull;
  Route<dynamic>? get current => _routes.lastOrNull;
  String? get currentName => current?.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    if (AppNavigation.primaryRoutes.contains(route.settings.name)) {
      lastMailboxRoute = route.settings.name!;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    if (AppNavigation.primaryRoutes.contains(previousRoute?.settings.name)) {
      lastMailboxRoute = previousRoute!.settings.name!;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == null) return;
    final index = _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) _routes[index] = newRoute;
  }
}

abstract final class AppNavigation {
  static const primaryRoutes = {
    '/all-senders',
    '/emails',
    '/unsubscribe',
    '/bulk-clean',
  };

  /// Back is reserved for reading, reviewing, and nested settings flows.
  /// Menu sections remain reachable through the account menu and bottom tabs.
  static const detailRoutes = {
    '/email-details',
    '/sender-details',
    '/alert-details',
    '/inbox-health',
    '/privacy-security',
    '/search-filter',
    '/block-senders',
    '/delete-emails',
    '/review-promotions',
  };

  static const utilityRoutes = {
    '/dashboard',
    '/inbox-health',
    '/security-alerts',
    '/block-senders',
    '/delete-emails',
    '/categories',
    '/review-promotions',
    '/search-filter',
    '/top-senders',
    '/activity',
    '/settings',
    '/connected-accounts',
    '/privacy-security',
    '/profile',
  };

  /// Tabs and tools fade on a stationary surface so their shared header does
  /// not slide sideways. Message/sender details retain the native back gesture.
  static PageRoute<void> route({
    required RouteSettings settings,
    required WidgetBuilder builder,
    bool disableAnimations = false,
  }) {
    if (!primaryRoutes.contains(settings.name) &&
        !utilityRoutes.contains(settings.name)) {
      return _DetailPageRoute(
        settings: settings,
        builder: builder,
        disableAnimations: disableAnimations,
      );
    }
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: disableAnimations ? Duration.zero : AppMotion.fast,
      reverseTransitionDuration: disableAnimations
          ? Duration.zero
          : AppMotion.fast,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation.drive(CurveTween(curve: AppMotion.enter)),
            child: child,
          ),
    );
  }

  static void open(
    BuildContext context,
    String name, {
    WidgetBuilder? builder,
  }) {
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final observer = navigator.widget.observers
        .whereType<AppNavigationObserver>()
        .firstOrNull;
    if (observer?.currentName == name &&
        observer?.current?.settings.arguments == null) {
      return;
    }
    if (observer == null &&
        ModalRoute.of(context)?.settings.name == name &&
        ModalRoute.of(context)?.settings.arguments == null) {
      return;
    }
    final existing = observer?.find(name);
    if (existing != null) {
      navigator.popUntil((route) => identical(route, existing));
    } else if (primaryRoutes.contains(name)) {
      // A main destination leaves utility/detail pages behind. Do not retain
      // Settings or a message underneath a newly selected mailbox tab.
      bool keepMailbox(Route<dynamic> route) =>
          primaryRoutes.contains(route.settings.name) &&
          route.settings.arguments == null;
      if (builder != null) {
        navigator.pushAndRemoveUntil(
          route(
            settings: RouteSettings(name: name),
            builder: builder,
            disableAnimations: MediaQuery.disableAnimationsOf(context),
          ),
          keepMailbox,
        );
      } else {
        navigator.pushNamedAndRemoveUntil(name, keepMailbox);
      }
    } else if (builder != null) {
      navigator.push(
        route(
          settings: RouteSettings(name: name),
          builder: builder,
          disableAnimations: MediaQuery.disableAnimationsOf(context),
        ),
      );
    } else {
      navigator.pushNamed(name);
    }
  }
}

/// Preserve platform Back gestures while respecting reduced-motion settings.
class _DetailPageRoute extends MaterialPageRoute<void> {
  _DetailPageRoute({
    required super.settings,
    required super.builder,
    required this.disableAnimations,
  });
  final bool disableAnimations;
  @override
  Duration get transitionDuration =>
      disableAnimations ? Duration.zero : super.transitionDuration;
  @override
  Duration get reverseTransitionDuration =>
      disableAnimations ? Duration.zero : super.reverseTransitionDuration;
}
