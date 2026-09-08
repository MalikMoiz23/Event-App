import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/ticket_code.dart';
import '../../models/ticket.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// Gate check-in.
///
/// This screen is used standing up, one-handed, with a queue waiting, so it
/// is built around three rules:
///
///  * **One thing at a time.** Scanning stops the moment a code is read and
///    does not resume until the result is dismissed. Without that, a code
///    held in front of the lens is read repeatedly and the verdict flickers
///    between "admitted" and "already used".
///  * **The verdict is unmissable.** Full-width, colour-coded, with an icon
///    and a word - never colour alone, because a red and a green card look
///    identical to a colourblind marshal in bright sun.
///  * **There is always a way through.** Cracked screens and dead phones are
///    normal at a gate, so the code can be typed in by hand.
///
/// The camera is only ever a reader. Whether a ticket is valid is decided by
/// `check_in_ticket` in the database, under a row lock, so two marshals
/// scanning the same pass cannot both admit it.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    // noDuplicates alone is not enough - it only suppresses the same code
    // twice in a row, and the queue's next ticket is a different code.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Blocks detections while a check-in is in flight or a result is showing.
  bool _paused = false;

  /// This session's tally, so whoever is on the gate can see it is working
  /// without leaving the screen.
  int _admitted = 0;
  int _rejected = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_paused) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere(
          (value) => value != null && value.isNotEmpty,
          orElse: () => null,
        );
    if (raw == null) return;

    final code = TicketCode.tryParse(raw);
    if (code == null) {
      // Somebody's boarding pass or a wifi QR. Say so quietly and keep
      // scanning rather than sending it to the database as a check-in.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1200),
          content: Text('That is not a HIT EVO ticket.'),
        ),
      );
      return;
    }

    await _checkIn(code);
  }

  Future<void> _checkIn(String code) async {
    setState(() => _paused = true);
    final service = context.read<TicketService>();

    try {
      final result = await service.checkIn(code);
      setState(() {
        if (result.admitted) {
          _admitted++;
        } else {
          _rejected++;
        }
      });
      if (!mounted) return;
      await _showVerdict(result);
    } on TicketException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _paused = false);
    }
  }

  Future<void> _showVerdict(CheckInResult result) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => _VerdictSheet(
        result: result,
        onUndo: result.admitted
            ? () async {
                await context.read<TicketService>().revertCheckIn(result.code);
                if (mounted) setState(() => _admitted--);
              }
            : null,
      ),
    );
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter ticket code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'HIT-0000-0000',
            helperText: 'Printed under the QR code on the pass',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Check in'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (code == null || !mounted) return;
    final parsed = TicketCode.tryParse(code);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That is not a valid ticket code.')),
      );
      return;
    }
    await _checkIn(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Black chrome: the preview fills the screen and a light app bar
      // floating over it looks like a rendering fault.
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Gate check-in'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Torch off' : 'Torch on',
                icon: Icon(
                  on
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                ),
                onPressed: state.isRunning ? _controller.toggleTorch : null,
              );
            },
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: _controller.switchCamera,
          ),
          Gap.w4,
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraError(error: error),
                ),
                const _Reticle(),
                if (_paused)
                  const ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          _Footer(
            admitted: _admitted,
            rejected: _rejected,
            onManualEntry: _enterManually,
          ),
        ],
      ),
    );
  }
}

/// The cut-out square. Purely a hint about where to hold the pass - the
/// decoder reads the whole frame - but without it people aim at the middle of
/// a black screen and guess.
class _Reticle extends StatelessWidget {
  const _Reticle();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 232,
              height: 232,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 2.5,
                ),
                borderRadius: Corner.lgAll,
              ),
            ),
            Gap.h16,
            Text(
              'Point at the QR code on the pass',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.admitted,
    required this.rejected,
    required this.onManualEntry,
  });

  final int admitted;
  final int rejected;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
        child: Row(
          children: [
            _Tally(
              value: admitted,
              label: 'admitted',
              color: AppColors.successDark,
            ),
            Gap.w16,
            _Tally(
              value: rejected,
              label: 'turned away',
              color: AppColors.dangerDark,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onManualEntry,
              icon: const Icon(Icons.keyboard_rounded, size: 18),
              label: const Text('Type code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
                minimumSize: const Size(0, 44),
                textStyle: text.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.value, required this.label, required this.color});

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: text.titleLarge?.copyWith(color: color, height: 1.1),
        ),
        Text(
          label,
          style: text.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

/// The verdict card.
///
/// Its own sheet rather than a snackbar: a snackbar times out, and the person
/// on the gate needs to be able to hold this up and read the attendee's name
/// off it before waving them through.
class _VerdictSheet extends StatelessWidget {
  const _VerdictSheet({required this.result, this.onUndo});

  final CheckInResult result;
  final Future<void> Function()? onUndo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    final (color, icon) = switch (result.verdict) {
      CheckInVerdict.ok => (
        AppColors.resolve(brightness, AppColors.success, AppColors.successDark),
        Icons.check_circle_rounded,
      ),
      CheckInVerdict.alreadyCheckedIn => (
        AppColors.resolve(brightness, AppColors.warning, AppColors.warningDark),
        Icons.replay_circle_filled_rounded,
      ),
      CheckInVerdict.waitlisted => (
        AppColors.resolve(brightness, AppColors.warning, AppColors.warningDark),
        Icons.hourglass_top_rounded,
      ),
      CheckInVerdict.cancelled => (
        AppColors.resolve(brightness, AppColors.danger, AppColors.dangerDark),
        Icons.block_rounded,
      ),
      CheckInVerdict.notFound => (
        AppColors.resolve(brightness, AppColors.danger, AppColors.dangerDark),
        Icons.help_rounded,
      ),
      CheckInVerdict.reverted => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        Icons.undo_rounded,
      ),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: color),
            ),
            Gap.h16,
            // The word, not just the colour.
            Text(
              result.headline,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(color: color),
            ),
            Gap.h8,
            Text(
              result.detail,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            if (result.attendeeName != null) ...[
              Gap.h20,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Column(
                    children: [
                      Text(result.attendeeName!, style: text.titleMedium),
                      if (result.eventName != null) ...[
                        Gap.h4,
                        Text(
                          result.eventName!,
                          textAlign: TextAlign.center,
                          style: text.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      Gap.h8,
                      Text(
                        result.code,
                        style: text.labelMedium?.copyWith(
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (result.checkedInAt != null) ...[
                        Gap.h8,
                        Text(
                          'Scanned ${Formatters.shortDateTime.format(result.checkedInAt!)}',
                          style: text.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            Gap.h24,
            Row(
              children: [
                if (onUndo != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await onUndo!();
                        navigator.pop();
                      },
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Undo'),
                    ),
                  ),
                  Gap.w12,
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Next ticket'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionDenied
                    ? Icons.no_photography_rounded
                    : Icons.videocam_off_rounded,
                size: 40,
                color: Colors.white70,
              ),
              Gap.h16,
              Text(
                permissionDenied
                    ? 'Camera access is off'
                    : 'The camera could not start',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              Gap.h8,
              Text(
                permissionDenied
                    ? 'Allow camera access for HIT EVO in your device '
                          'settings, then come back. You can still type codes '
                          'in by hand.'
                    : 'Close anything else using the camera and try again. '
                          'You can still type codes in by hand.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
