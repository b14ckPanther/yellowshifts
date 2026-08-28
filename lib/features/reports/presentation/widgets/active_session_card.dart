import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/open_attendance_session.dart';

class ActiveSessionCard extends StatefulWidget {
  final OpenAttendanceSession session;
  final VoidCallback? onTap;

  const ActiveSessionCard({
    super.key,
    required this.session,
    this.onTap,
  });

  @override
  State<ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<ActiveSessionCard> {
  late Timer _ticker;
  late int _currentElapsed;

  @override
  void initState() {
    super.initState();
    _currentElapsed = widget.session.elapsedMinutes;
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          final diff = now.difference(widget.session.checkInTime).inMinutes;
          _currentElapsed = diff > 0 ? diff : 0;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ActiveSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.checkInTime != widget.session.checkInTime) {
      final now = DateTime.now();
      _currentElapsed =
          now.difference(widget.session.checkInTime).inMinutes.clamp(0, 99999);
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _formatElapsed(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isWarning = widget.session.needsAttention || _currentElapsed >= 960;

    final primaryColor = isWarning
        ? const Color(0xFFF59E0B) // Amber
        : const Color(0xFF10B981); // Emerald Green

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.activeShiftInProgress,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatElapsed(_currentElapsed),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.stationName.isNotEmpty
                                ? widget.session.stationName
                                : l10n.stationLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.session.shiftNameSnapshot != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.session.shiftNameSnapshot!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.checkedInLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatTime(widget.session.checkInTime),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isWarning) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.shiftExceedsWarning,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
