import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../core/nfc/nfc_service.dart';
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
  bool _isWritingNfc = false;
  String? _errorMessage;
  NfcStationTagPayload? _provisionedPayload;
  String? _tagIdentifier;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

      final payload = NfcStationTagPayload(
        version: 1,
        stationCode: res['station_code'] as String? ?? '',
        tagIdentifier: res['tag_identifier'] as String? ?? '',
        rawSecret: res['raw_secret'] as String? ?? '',
      );

      ref.invalidate(stationNfcTagsProvider(widget.stationId));

      if (!mounted) return;
      setState(() {
        _isProvisioningOnServer = false;
        _provisionedPayload = payload;
        _tagIdentifier = payload.tagIdentifier;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProvisioningOnServer = false;
        _errorMessage = ErrorLocalizer.localize(e, l10n);
      });
    }
  }

  Future<void> _handleWriteNfc() async {
    if (_provisionedPayload == null) return;
    final l10n = AppLocalizations.of(context)!;
    final nfcService = ref.read(nfcServiceProvider);

    final isAvail = await nfcService.isAvailable();
    if (!isAvail) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.nfcUnavailableError),
            backgroundColor: AppColors.colorWarning,
          ),
        );
      }
      return;
    }

    setState(() {
      _isWritingNfc = true;
      _errorMessage = null;
    });

    await nfcService.writeStationTag(
      payload: _provisionedPayload!,
      alertMessage: l10n.nfcHoldToWritePrompt,
      onSuccess: () {
        if (!mounted) return;
        setState(() {
          _isWritingNfc = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.nfcTagWrittenSuccess),
            backgroundColor: AppColors.colorSuccess,
          ),
        );
        Navigator.of(context).pop(true);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isWritingNfc = false;
          _errorMessage = err;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: AppColors.colorSurfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(LucideIcons.radio, color: AppColors.colorTextPrimary),
          const SizedBox(width: AppSpacing.space8),
          Text(
            _provisionedPayload == null
                ? l10n.nfcProvisionNewTitle
                : l10n.nfcWriteTagTitle,
            style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_provisionedPayload == null) ...[
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              Text(
                l10n.nfcTagCreatedServerDesc,
                style: typography.bodyMedium
                    .copyWith(color: AppColors.colorTextSecondary),
              ),
              const SizedBox(height: AppSpacing.space12),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space12),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceBase,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.colorBorderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.nfcTagIdLabel}: $_tagIdentifier',
                      style: typography.bodyStrong,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.nfcStationCodeLabel}: ${_provisionedPayload?.stationCode}',
                      style: typography.caption
                          .copyWith(color: AppColors.colorTextSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              Text(
                l10n.nfcReadyToWriteDesc,
                style: typography.bodySmall
                    .copyWith(color: AppColors.colorTextMuted),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dialogCancel),
        ),
        if (_provisionedPayload == null)
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
          )
        else ...[
          ElevatedButton.icon(
            onPressed: _isWritingNfc ? null : _handleWriteNfc,
            icon: const Icon(LucideIcons.radio, size: 16),
            label: _isWritingNfc
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.nfcWriteToCardAction),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorSurfaceBrand,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ],
    );
  }
}
