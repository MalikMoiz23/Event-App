import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_index.dart';
import '../../models/ticket.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/app_dimens.dart';
import '../../theme/hit_logo.dart';

/// Account, appearance and sign-out.
///
/// The theme control and the sign-out button used to be two icons in the
/// Discover app bar, competing with search for the same strip of space and
/// putting a destructive action one mis-tap from a filter. Both belong on a
/// settings surface, which is also somewhere the attendee's own numbers can
/// live.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final tickets = context.watch<List<Ticket>>();
    final saved = context.watch<FavoriteIndex>();

    final booked = tickets.where((t) => t.isActive).length;
    final attended = tickets.where((t) => t.isCheckedIn).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: Gap.listInsets,
        children: [
          _IdentityCard(profile: profile),
          Gap.h16,
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.confirmation_number_outlined,
                  value: '$booked',
                  label: 'Tickets',
                ),
              ),
              Gap.w12,
              Expanded(
                child: _MiniStat(
                  icon: Icons.how_to_reg_outlined,
                  value: '$attended',
                  label: 'Attended',
                ),
              ),
              Gap.w12,
              Expanded(
                child: _MiniStat(
                  icon: Icons.bookmark_outline_rounded,
                  value: '${saved.count}',
                  label: 'Saved',
                ),
              ),
            ],
          ),

          Gap.h24,
          _SettingsGroup(title: 'Appearance', children: [const _ThemePicker()]),

          Gap.h16,
          _SettingsGroup(
            title: 'About',
            children: [
              const ListTile(
                leading: HitLogo(size: 26),
                title: Text('HIT EVO'),
                subtitle: Text('Version 1.1.0'),
                contentPadding: EdgeInsets.symmetric(horizontal: Gap.lg),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final authService = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your tickets stay on your account and come back when you sign in '
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
    if (confirmed == true) await authService.signOut();
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final UserProfile profile;

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
                  _initials(profile.fullName),
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
  /// AMH. Falls back to the first character for a single-word name.
  static String _initials(String name) {
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

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

/// Three explicit choices rather than a switch, so "match system" stays
/// reachable once the user has picked a side.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

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
