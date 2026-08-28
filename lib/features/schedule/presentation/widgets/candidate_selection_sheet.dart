import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../domain/models/work_schedule_shift.dart';
import '../../domain/models/schedule_candidate.dart';
import '../controllers/scheduling_controller.dart';

class CandidateSelectionSheet extends ConsumerStatefulWidget {
  final WorkScheduleShift shift;
  final int currentScheduleVersion;
  final bool isPublished;

  const CandidateSelectionSheet({
    super.key,
    required this.shift,
    required this.currentScheduleVersion,
    required this.isPublished,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkScheduleShift shift,
    required int currentScheduleVersion,
    required bool isPublished,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CandidateSelectionSheet(
        shift: shift,
        currentScheduleVersion: currentScheduleVersion,
        isPublished: isPublished,
      ),
    );
  }

  @override
  ConsumerState<CandidateSelectionSheet> createState() =>
      _CandidateSelectionSheetState();
}

class _CandidateSelectionSheetState
    extends ConsumerState<CandidateSelectionSheet> {
  String _searchQuery = '';
  String _activeFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCandidateAssign(ScheduleCandidate candidate) async {
    String? overrideReason;
    String? changeReason;

    // Prompt for Override Reason if employee is unavailable or not submitted
    if (candidate.requiresOverride) {
      final reason = await _showReasonDialog(
        title: 'אישור חריגת זמינות',
        subtitle:
            'העובד ${candidate.fullName} לא הגיש זמינות או סימן שאינו זמין. יש להזין סיבה לשיבוץ:',
        hint: 'למשל: סוכם טלפונית / תגבור דחוף',
        isRequired: true,
      );
      if (reason == null || reason.trim().length < 3) return;
      overrideReason = reason.trim();
    }

    // Prompt for Change Reason if schedule is already PUBLISHED
    if (widget.isPublished) {
      final reason = await _showReasonDialog(
        title: 'סיבת שינוי לוח רשמי',
        subtitle: 'הלוח כבר פורסם. יש להזין סיבה לשינוי השיבוץ בלוח הרשמי:',
        hint: 'למשל: מחלה / החלפת משמרות',
        isRequired: true,
      );
      if (reason == null || reason.trim().length < 3) return;
      changeReason = reason.trim();
    }

    if (!mounted) return;

    try {
      await ref.read(schedulingControllerProvider.notifier).assignEmployee(
            scheduleShiftId: widget.shift.id,
            membershipId: candidate.membershipId,
            expectedVersion: widget.currentScheduleVersion,
            override: candidate.requiresOverride,
            overrideReason: overrideReason,
            changeReason: changeReason,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.colorStatusSuccess,
            content: Text('${candidate.fullName} שובץ בהצלחה למשמרת'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.colorStatusDanger,
            content: Text('שגיאה בשיבוץ: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<String?> _showReasonDialog({
    required String title,
    required String subtitle,
    required String hint,
    required bool isRequired,
  }) {
    final textController = TextEditingController();
    const typography = AppTypography();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.colorSurfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          side: const BorderSide(color: AppColors.colorBorderSubtle),
        ),
        title: Text(title, style: typography.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(subtitle, style: typography.bodyMedium),
            const SizedBox(height: AppSpacing.space16),
            TextField(
              controller: textController,
              autofocus: true,
              style: typography.bodyMedium,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: typography.caption,
                filled: true,
                fillColor: AppColors.colorSurfaceBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  borderSide:
                      const BorderSide(color: AppColors.colorBorderSubtle),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (isRequired && text.length < 3) return;
              Navigator.of(ctx).pop(text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorBrandYellow,
              foregroundColor: AppColors.colorTextPrimary,
            ),
            child: const Text('אישור'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final candidatesAsync = ref.watch(shiftCandidatesProvider((
      shiftId: widget.shift.id,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      filter: _activeFilter,
    )));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.colorSurfaceBase,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.space12),
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: AppColors.colorBorderSubtle,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'שיבוץ עובדים — ${widget.shift.shiftName}',
                        style: typography.titleLarge,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        '${widget.shift.startTime} – ${widget.shift.endTime} | דרושים: ${widget.shift.requiredStaffCount} | שובצו: ${widget.shift.assignedStaffCount}',
                        style: typography.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20.0),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Search & Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.search, size: 18.0),
                    hintText: 'חיפוש לפי שם או קוד עובד...',
                    filled: true,
                    fillColor: AppColors.colorSurfaceRaised,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space12,
                      vertical: AppSpacing.space8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                      borderSide:
                          const BorderSide(color: AppColors.colorBorderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'הכל', typography),
                      _buildFilterChip('AVAILABLE', 'זמינים', typography),
                      _buildFilterChip('UNAVAILABLE', 'לא זמינים', typography),
                      _buildFilterChip('NOT_SUBMITTED', 'לא הגישו', typography),
                      _buildFilterChip('CONFLICT', 'חפיפות', typography),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.space16),
          // Candidates List
          Expanded(
            child: candidatesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
              error: (err, _) => Center(
                child: Text('שגיאה בטעינת מועמדים: $err',
                    style: typography.bodyMedium),
              ),
              data: (candidates) {
                if (candidates.isEmpty) {
                  return const Center(
                    child: Text('לא נמצאו עובדים מתאימים לסינון זה'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: AppSpacing.space8,
                  ),
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.space8),
                  itemBuilder: (context, index) {
                    final cand = candidates[index];
                    return _buildCandidateCard(cand, typography);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, AppTypography typography) {
    final isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.space8),
      child: ChoiceChip(
        label: Text(label, style: typography.caption),
        selected: isSelected,
        onSelected: (_) => setState(() => _activeFilter = key),
        selectedColor: AppColors.colorSurfaceBrandAccent,
        backgroundColor: AppColors.colorSurfaceRaised,
      ),
    );
  }

  Widget _buildCandidateCard(
      ScheduleCandidate candidate, AppTypography typography) {
    Color availColor = AppColors.colorTextMuted;
    String availLabel = 'לא הגיש';
    if (candidate.availabilityState == CandidateAvailabilityState.available) {
      availColor = AppColors.colorStatusSuccess;
      availLabel = 'זמין';
    } else if (candidate.availabilityState ==
        CandidateAvailabilityState.unavailable) {
      availColor = AppColors.colorStatusDanger;
      availLabel = 'לא זמין';
    }

    final hasConflict = candidate.conflictState.hasConflict;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: candidate.alreadyAssigned
            ? AppColors.colorSurfaceBrandAccent.withValues(alpha: 0.3)
            : AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: candidate.alreadyAssigned
              ? AppColors.colorBrandYellow
              : AppColors.colorBorderSubtle,
        ),
      ),
      child: Row(
        children: [
          // Avatar Initial
          CircleAvatar(
            radius: 18.0,
            backgroundColor: AppColors.colorSurfaceBase,
            child: Text(
              candidate.firstName.isNotEmpty
                  ? candidate.firstName[0].toUpperCase()
                  : '?',
              style: typography.bodyStrong,
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          // Name & Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      candidate.fullName,
                      style: typography.bodyStrong,
                    ),
                    if (candidate.employeeCode != null) ...[
                      const SizedBox(width: AppSpacing.space6),
                      Text(
                        '(${candidate.employeeCode})',
                        style: typography.caption,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    // Availability Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space6,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: availColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(
                            color: availColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        availLabel,
                        style: typography.caption.copyWith(
                          color: availColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space6),
                    Text(
                      'משמרות השבוע: ${candidate.weeklyShiftsCount}',
                      style: typography.caption.copyWith(fontSize: 11.0),
                    ),
                  ],
                ),
                if (hasConflict) ...[
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      const Icon(LucideIcons.triangleAlert,
                          size: 12.0, color: AppColors.colorStatusDanger),
                      const SizedBox(width: 4.0),
                      Text(
                        candidate.conflictState ==
                                CandidateConflictState.crossStationOverlap
                            ? 'חפיפה בתחנה אחרת'
                            : 'חפיפת משמרות באותה שעה',
                        style: typography.caption.copyWith(
                          color: AppColors.colorStatusDanger,
                          fontSize: 11.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Action Button
          if (candidate.alreadyAssigned)
            const Chip(
              label: Text('משובץ', style: TextStyle(fontSize: 11.0)),
              backgroundColor: AppColors.colorSurfaceBrandAccent,
            )
          else
            ElevatedButton(
              onPressed:
                  hasConflict ? null : () => _handleCandidateAssign(candidate),
              style: ElevatedButton.styleFrom(
                backgroundColor: candidate.requiresOverride
                    ? AppColors.colorStatusWarning
                    : AppColors.colorBrandYellow,
                foregroundColor: AppColors.colorTextPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
              child: Text(
                candidate.requiresOverride ? 'שבץ עם חריגה' : 'שבץ',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
