import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/nfc_providers.dart';

class NfcProvisionDialog extends ConsumerStatefulWidget {
  final String stationId;

  const NfcProvisionDialog({
    super.key,
    required this.stationId,
  });

  @override
  ConsumerState<NfcProvisionDialog> createState() => _NfcProvisionDialogState();
}

class _NfcProvisionDialogState extends ConsumerState<NfcProvisionDialog> {
  final _nameController = TextEditingController();
  bool _isProvisioningOnServer = false;
  String? _errorMessage;
  String? _provisionedUrl;
  String? _tagIdentifier;
  String? _tagName;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _buildFullNfcUrl(String token) {
    if (kIsWeb) {
      final base = Uri.base;
      final portStr = (base.hasPort && base.port != 80 && base.port != 443)
          ? ':${base.port}'
          : '';
      final origin = '${base.scheme}://${base.host}$portStr';
      return '$origin/nfc/t/$token';
    }
    return 'https://app.yellowshifts.com/nfc/t/$token';
  }

  Future<void> _handleProvision() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProvisioningOnServer = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(nfcTagRepositoryProvider);
      final res = await repo.provisionStationNfcTag(
        stationId: widget.stationId,
        name: name,
      );

      final token =
          res['token'] as String? ?? res['raw_secret'] as String? ?? '';
      final fullUrl = _buildFullNfcUrl(token);

      ref.invalidate(stationNfcTagsProvider(widget.stationId));

      if (!mounted) return;
      setState(() {
        _isProvisioningOnServer = false;
        _tagName = res['name'] as String? ?? name;
        _tagIdentifier = res['tag_identifier'] as String? ?? '';
        _provisionedUrl = fullUrl;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProvisioningOnServer = false;
        _errorMessage = ErrorLocalizer.localize(e, l10n);
      });
    }
  }

  void _copyUrlToClipboard(AppLocalizations l10n) {
    if (_provisionedUrl == null) return;
    Clipboard.setData(ClipboardData(text: _provisionedUrl!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.nfcUrlCopiedToast),
        backgroundColor: AppColors.colorSuccess,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: AppColors.colorSurfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      title: Row(
        children: [
          const Icon(LucideIcons.radio, color: AppColors.colorTextPrimary),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Text(
              _provisionedUrl == null
                  ? l10n.nfcProvisionNewTitle
                  : l10n.nfcTagUrlLabel,
              style:
                  typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_provisionedUrl == null) ...[
              Text(
                l10n.nfcProvisionDialogDesc,
                style: typography.bodyMedium
                    .copyWith(color: AppColors.colorTextSecondary),
              ),
              const SizedBox(height: AppSpacing.space16),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.nfcTagNameLabel,
                  hintText: l10n.nfcTagNameHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.space12),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceBase,
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  border: Border.all(color: AppColors.colorBorderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tagName ?? '',
                      style: typography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.colorTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.nfcTagIdLabel}: $_tagIdentifier',
                      style: typography.caption.copyWith(
                        color: AppColors.colorTextSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              Text(
                l10n.nfcTagUrlLabel,
                style: typography.bodyStrong.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.colorTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceBase,
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  border: Border.all(color: AppColors.colorBorderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _provisionedUrl!,
                        style: typography.bodySmall.copyWith(
                          fontFamily: 'monospace',
                          color: AppColors.colorTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 18),
                      tooltip: l10n.nfcCopyUrlAction,
                      onPressed: () => _copyUrlToClipboard(l10n),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space12),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceBrandSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.info,
                      size: 18,
                      color: AppColors.colorTextPrimary,
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Expanded(
                      child: Text(
                        l10n.nfcNdefWriteInstructions,
                        style: typography.caption.copyWith(
                          color: AppColors.colorTextPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.space12),
              Text(
                _errorMessage!,
                style: typography.caption.copyWith(color: AppColors.colorError),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_provisionedUrl == null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.dialogCancel),
          ),
          ElevatedButton(
            onPressed: _isProvisioningOnServer ? null : _handleProvision,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorSurfaceBrand,
              foregroundColor: Colors.black,
            ),
            child: _isProvisioningOnServer
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.nfcCreateTagAction),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: () => _copyUrlToClipboard(l10n),
            icon: const Icon(LucideIcons.copy, size: 16),
            label: Text(l10n.nfcCopyUrlAction),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorSurfaceBrand,
              foregroundColor: Colors.black,
            ),
            child: Text(l10n.dialogOk),
          ),
        ],
      ],
    );
  }
}
