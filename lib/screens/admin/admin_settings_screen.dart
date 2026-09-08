import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event.dart';
import '../../models/event_index.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/hit_logo.dart';
import '../../widgets/settings_widgets.dart';

/// Admin account and appearance.
///
/// Shares its parts with the attendee profile screen; what differs is the
/// three figures at the top, which here are about the events this admin is
/// responsible for rather than tickets they hold.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<EventStatsIndex>();

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: Gap.listInsets,
        children: [
          IdentityCard(
            profile: profile,
            caption: 'Full access to events, attendees and check-in',
          ),
          Gap.h16,
          StreamBuilder<List<Event>>(
            stream: context.read<EventService>().watchEvents(),
            builder: (context, snapshot) {
              final events = snapshot.data ?? const <Event>[];
              final live = events
                  .where((e) => e.statusAt(DateTime.now()) != EventStatus.past)
                  .length;
              return Row(
                children: [
                  Expanded(
                    child: MiniStat(
                      icon: Icons.event_outlined,
                      value: '${events.length}',
                      label: 'Events',
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: MiniStat(
                      icon: Icons.upcoming_outlined,
                      value: '$live',
                      label: 'Live',
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: MiniStat(
                      icon: Icons.how_to_reg_outlined,
                      value: '${stats.totalCheckedIn}',
                      label: 'Scanned',
                    ),
                  ),
                ],
              );
            },
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
                    'You will need to sign back in before you can scan '
                    'tickets or publish events.',
                onSignOut: context.read<AuthService>().signOut,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
