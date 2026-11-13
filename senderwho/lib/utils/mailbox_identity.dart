import '../models/app_models.dart';

/// The visible mailbox identity, separate from the SenderWho sign-in identity.
class MailboxIdentity {
  const MailboxIdentity({required this.name, this.email, this.avatarUrl});

  final String name;
  final String? email;
  final String? avatarUrl;

  factory MailboxIdentity.resolve({
    ConnectedEmailAccount? mailbox,
    UserProfile? profile,
    String? userEmail,
  }) {
    final email = mailbox?.emailAddress.trim().isNotEmpty == true
        ? mailbox!.emailAddress.trim()
        : profile?.email ?? userEmail;
    final matchesProfile =
        email != null &&
        profile?.email.trim().toLowerCase() == email.toLowerCase();
    final displayName = mailbox?.displayName.trim() ?? '';
    final providerLabel = {
      'GOOGLE',
      'GMAIL',
      'MICROSOFT',
      'OUTLOOK',
      'YAHOO',
    }.contains(displayName.toUpperCase());
    return MailboxIdentity(
      name: displayName.isNotEmpty && !providerLabel
          ? displayName
          : matchesProfile
          ? profile!.name
          : email?.split('@').first ?? 'My account',
      email: email,
      // Never show the original user's photo for a different mailbox.
      avatarUrl:
          mailbox?.avatarUrl ?? (matchesProfile ? profile!.avatarUrl : null),
    );
  }
}
