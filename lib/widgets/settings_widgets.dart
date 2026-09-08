import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/theme_controller.dart';
import '../theme/app_dimens.dart';

/// The pieces both the attendee and admin settings screens are built from.
///
/// Shared rather than duplicated because the two screens differ only in what
/// they count and which actions they offer - everything around that is the
/// same, and two copies of it would drift apart on the first change.

/// Who is signed in.
class IdentityCard extends StatelessWidget {
  const IdentityCard({super.key, required this.profile, this.caption});

  final UserProfile profile;

  /// Extra line under the email, e.g. how long the account has existed.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initialsOf(profile.fullName),
                  style: text.titleLarge?.copyWith(color: scheme.primary),
                ),
              ),
            ),
            Gap.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName, style: text.titleMedium),
                  Gap.h2,
                  Text(
                    profile.email,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (caption != null) ...[
                    Gap.h2,
                    Text(
                      caption!,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (profile.isAdmin)
              Chip(
                label: const Text('Admin'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  /// First and last initial, so "Abdul Moiz Haroon" reads as AH rather than
  /// AMH. Falls back to one character for a single-word name.
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// A titled block of rows inside one card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.sm),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xs),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

/// One small figure in a row of three.
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.lg,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            Gap.h8,
            Text(value, style: text.titleLarge),
            Gap.h2,
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three explicit choices rather than a switch, so "match system" stays
/// reachable once the user has picked a side.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.contrast_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Gap.w12,
              Text('Theme', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          Gap.h12,
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 16),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 16),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.smartphone_rounded, size: 16),
                label: Text('System'),
              ),
            ],
            selected: {controller.mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                controller.setMode(selection.first),
          ),
        ],
      ),
    );
  }
}

/// Sign-out row plus its confirmation.
///
/// Confirmed rather than immediate: it is the last row on a scrolling
/// settings list, which is exactly where a thumb lands by accident.
class SignOutTile extends StatelessWidget {
  const SignOutTile({super.key, required this.onSignOut, this.message});

  final Future<void> Function() onSignOut;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.logout_rounded),
      title: const Text('Sign out'),
      textColor: scheme.error,
      iconColor: scheme.error,
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sign out?'),
            content: Text(
              message ??
                  'Everything on your account comes back when you sign in '
                      'again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay signed in'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
        if (confirmed == true) await onSignOut();
      },
    );
  }
}
