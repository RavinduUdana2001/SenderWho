import 'package:flutter/widgets.dart';
import 'senderwho_repository.dart';

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });
  final SenderWhoRepository repository;
  static SenderWhoRepository read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RepositoryScope>()?.repository ??
      senderWhoRepository;
  @override
  bool updateShouldNotify(RepositoryScope oldWidget) =>
      repository != oldWidget.repository;
}
