import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_index.dart';
import '../../models/ticket.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/hit_logo.dart';
import '../../widgets/settings_widgets.dart';

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
          IdentityCard(profile: profile),
          Gap.h16,
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  icon: Icons.confirmation_number_outlined,
                  value: '$booked',
                  label: 'Tickets',
                ),
              ),
              Gap.w12,
              Expanded(
                child: MiniStat(
                  icon: Icons.how_to_reg_outlined,
                  value: '$attended',
                  label: 'Attended',
                ),
              ),
              Gap.w12,
              Expanded(
                child: MiniStat(
                  icon: Icons.bookmark_outline_rounded,
                  value: '${saved.count}',
                  label: 'Saved',
                ),
              ),
            ],
          ),

          Gap.h24,
          const SettingsGroup(title: 'Appearance', children: [ThemePicker()]),

          Gap.h16,
          SettingsGroup(
            title: 'About',
            children: [
              const ListTile(
                leading: HitLogo(size: 26),
                title: Text('HIT EVO'),
                subtitle: Text('Version 1.1.0'),
                contentPadding: EdgeInsets.symmetric(horizontal: Gap.lg),
              ),
              SignOutTile(
                message:
                    'Your tickets stay on your account and come back when '
                    'you sign in again.',
                onSignOut: context.read<AuthService>().signOut,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
