import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Voice recording button — disabled for trial version.
/// Shows a beautiful "Coming Soon" state with organic styling.
class RaimbleRecordButton extends ConsumerWidget {
  final bool isGeneralDashboard;
  final String? targetClientId;

  const RaimbleRecordButton({
    Key? key,
    this.isGeneralDashboard = true,
    this.targetClientId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Voice recording will be available in a future update.',
                    style: GoogleFonts.outfit(fontSize: 13),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.9),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.hintColor.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
          ),
          // Main button — greyed out
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.hintColor.withValues(alpha: 0.15),
              border: Border.all(
                color: theme.hintColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic_off_rounded,
                  color: theme.hintColor.withValues(alpha: 0.4),
                  size: 22,
                ),
                Text(
                  'Soon',
                  style: GoogleFonts.outfit(
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                    color: theme.hintColor.withValues(alpha: 0.4),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
