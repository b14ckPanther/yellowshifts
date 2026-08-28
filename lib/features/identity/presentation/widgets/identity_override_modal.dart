import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../providers/identity_providers.dart';

class IdentityOverrideModal extends ConsumerStatefulWidget {
  final String presenceProofToken;
  final Function(String overrideProofToken) onOverrideCreated;

  const IdentityOverrideModal({
    super.key,
    required this.presenceProofToken,
    required this.onOverrideCreated,
  });

  static Future<void> show({
    required BuildContext context,
    required String presenceProofToken,
    required Function(String overrideProofToken) onOverrideCreated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IdentityOverrideModal(
        presenceProofToken: presenceProofToken,
        onOverrideCreated: onOverrideCreated,
      ),
    );
  }

  @override
  ConsumerState<IdentityOverrideModal> createState() =>
      _IdentityOverrideModalState();
}

class _IdentityOverrideModalState extends ConsumerState<IdentityOverrideModal> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      setState(() {
        _errorMessage = 'Reason must be at least 3 characters long.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(identityRepositoryProvider);
      final proof = await repo.createIdentityAdminOverride(
        presenceProofToken: widget.presenceProofToken,
        reason: reason,
      );

      if (!mounted) return;
      if (proof.identityProofToken != null) {
        Navigator.pop(context);
        widget.onOverrideCreated(proof.identityProofToken!);
      } else {
        setState(() {
          _errorMessage = 'Failed to generate override token.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.space24,
        left: AppSpacing.space20,
        right: AppSpacing.space20,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.colorWarning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: AppColors.colorWarning),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manager Identity Override',
                        style: typography.titleMedium),
                    Text(
                      'Authorize manual check-in with audit logging',
                      style: typography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          Text(
            'This action records a MANUAL_ADMIN verification method in the audit ledger. A valid reason is required.',
            style: typography.caption
                .copyWith(color: AppColors.colorTextSecondary),
          ),
          const SizedBox(height: AppSpacing.space16),
          AppTextField(
            controller: _reasonController,
            label: 'Override Reason (Mandatory)',
            hint: 'e.g. Employee camera malfunction confirmed in-person',
            maxLines: 2,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.space8),
            Text(
              _errorMessage!,
              style: typography.caption.copyWith(color: AppColors.colorError),
            ),
          ],
          const SizedBox(height: AppSpacing.space20),
          AppButton(
            label: 'Authorize Exception',
            isLoading: _isLoading,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
