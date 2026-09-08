import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import 'admin_analytics_screen.dart';
import 'admin_events_screen.dart';
import 'admin_settings_screen.dart';
import 'scanner_screen.dart';

/// The admin's four tabs.
///
/// Analytics and sign-out used to be two icons in the event list's app bar,
/// which left no room at all for check-in - the one thing an admin does while
/// standing up.
///
/// The scanner is deliberately *not* kept alive in the [IndexedStack] with
/// the others. Holding a camera session open behind three other tabs drains
/// the battery of the phone being used on the gate and keeps the torch
/// hardware claimed; it is built fresh on entry and torn down on exit
/// instead. Everything else keeps its state, since scroll position and live
/// subscriptions are worth preserving.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const int _scannerIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _index == _scannerIndex
          ? const ScannerScreen()
          : IndexedStack(
              index: _index,
              children: [
                AdminEventsScreen(profile: widget.profile),
                // Placeholder for the scanner slot, so the indices still
                // line up with the destinations below.
                const SizedBox.shrink(),
                const AdminAnalyticsScreen(),
                AdminSettingsScreen(profile: widget.profile),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (next) => setState(() => _index = next),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Check in',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
