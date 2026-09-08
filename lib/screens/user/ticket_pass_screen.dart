import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/formatters.dart';
import '../../core/launchers.dart';
import '../../core/ticket_code.dart';
import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/status_badge.dart';

/// The pass shown at the gate.
///
/// Two constraints shape this screen:
///
///  * **The QR is always dark-on-white**, whatever the app theme. A scanner
///    reads the contrast between modules and quiet zone; an inverted code on
///    a dark card is unreadable by most of them, which would make dark mode
///    quietly break the one thing this screen is for.
///  * **The code is legible as text too**, in a large monospaced-figure
///    style, because gates lose signal, screens crack, and someone will read
///    it out.
class TicketPassScreen extends StatelessWidget {
  const TicketPassScreen({
    super.key,
    required this.ticket,
    required this.event,
  });

  final Ticket ticket;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final scannable = ticket.status == TicketStatus.confirmed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your pass'),
        actions: [
          IconButton(
            tooltip: 'Add to calendar',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => Launchers.addToCalendar(event),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.lg,
          Gap.page,
          Gap.xxxl,
        ),
        children: [
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(Gap.xl),
                  child: Column(
                    children: [
                      TicketStatusBadge(status: ticket.status),
                      Gap.h20,

                      // Fixed white plate with its own quiet-zone padding.
                      Container(
                        padding: const EdgeInsets.all(Gap.lg),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: Corner.mdAll,
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: scannable
                            ? QrImageView(
                                data: TicketCode.encode(ticket.code),
                                version: QrVersions.auto,
                                size: 208,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              )
                            : SizedBox(
                                width: 208,
                                height: 208,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(Gap.lg),
                                    child: Text(
                                      _unscannableReason(ticket.status),
                                      textAlign: TextAlign.center,
                                      style: text.bodyMedium?.copyWith(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),

                      Gap.h20,
                      SelectableText(
                        ticket.code,
                        style: text.headlineSmall?.copyWith(
                          letterSpacing: 2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Gap.h4,
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: ticket.code),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ticket code copied.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy code'),
                      ),
                    ],
                  ),
                ),

                // The perforation. Purely decorative, but it is what makes
                // the card read as a ticket at a glance.
                const _Perforation(),

                Padding(
                  padding: const EdgeInsets.all(Gap.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.name, style: text.titleLarge),
                      Gap.h16,
                      _PassRow(
                        label: 'When',
                        value: Formatters.fullDateTime.format(event.eventDate),
                      ),
                      if (event.venueLine != null)
                        _PassRow(label: 'Where', value: event.venueLine!),
                      _PassRow(
                        label: 'Entry',
                        value: Formatters.price(event.charges),
                      ),
                      _PassRow(
                        label: 'Booked',
                        value: Formatters.shortDateTime.format(ticket.bookedAt),
                      ),
                      if (ticket.checkedInAt != null)
                        _PassRow(
                          label: 'Checked in',
                          value: Formatters.shortDateTime.format(
                            ticket.checkedInAt!,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (scannable) ...[
            Gap.h16,
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                Gap.w8,
                Expanded(
                  child: Text(
                    'Turn your screen brightness up before you reach the gate.',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _unscannableReason(TicketStatus status) => switch (status) {
    TicketStatus.waitlisted =>
      'No pass yet. A code appears here if a seat opens up.',
    TicketStatus.cancelled => 'This booking was cancelled.',
    TicketStatus.checkedIn => 'Already checked in.',
    TicketStatus.confirmed => '',
  };
}

class _PassRow extends StatelessWidget {
  const _PassRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label.toUpperCase(),
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

/// A dashed rule with a notch cut into each edge.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          _Notch(color: scheme.surfaceContainerLow),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dashWidth = 5.0;
                final dashes = (constraints.maxWidth / (dashWidth * 2)).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    dashes,
                    (_) => SizedBox(
                      width: dashWidth,
                      height: 1,
                      child: ColoredBox(color: scheme.outlineVariant),
                    ),
                  ),
                );
              },
            ),
          ),
          _Notch(color: scheme.surfaceContainerLow),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
