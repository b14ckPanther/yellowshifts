import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/models/qr_challenge.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../l10n/app_localizations.dart';

class DynamicQrDisplay extends ConsumerStatefulWidget {
  final QrChallenge challenge;
  final VoidCallback onRefresh;
  final bool isOffline;

  const DynamicQrDisplay({
    super.key,
    required this.challenge,
    required this.onRefresh,
    this.isOffline = false,
  });

  @override
  ConsumerState<DynamicQrDisplay> createState() => _DynamicQrDisplayState();
}

class _DynamicQrDisplayState extends ConsumerState<DynamicQrDisplay> {
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateRemainingTime();
    });
  }

  @override
  void didUpdateWidget(covariant DynamicQrDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenge.qrToken != widget.challenge.qrToken) {
      _updateRemainingTime();
    }
  }

  void _updateRemainingTime() {
    final now = DateTime.now().toUtc();
    final remaining = widget.challenge.expiresAt.difference(now).inSeconds;
    if (remaining <= 0) {
      if (mounted) {
        setState(() {
          _secondsLeft = 0;
        });
        widget.onRefresh();
      }
    } else {
      if (mounted) {
        setState(() {
          _secondsLeft = remaining;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectivityProvider);
    final isDisconnected = widget.isOffline || connectionState.isOffline;
    final l10n = AppLocalizations.of(context);
    const typography = AppTypography();
    final progress =
        (_secondsLeft / widget.challenge.ttlSeconds).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.space24),
          decoration: BoxDecoration(
            color: AppColors.colorSurfaceRaised,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDisconnected
                  ? AppColors.colorError
                  : AppColors.colorBorderSubtle,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Opacity(
                      opacity: isDisconnected ? 0.08 : 1.0,
                      child: QrImageView(
                        data: isDisconnected
                            ? 'OFFLINE'
                            : widget.challenge.qrToken,
                        version: QrVersions.auto,
                        size: 260.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF1E293B),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  if (isDisconnected)
                    Container(
                      width: 260.0,
                      height: 260.0,
                      decoration: BoxDecoration(
                        color:
                            AppColors.colorSurfaceBase.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.wifiOff,
                            size: 48,
                            color: AppColors.colorError,
                          ),
                          const SizedBox(height: AppSpacing.space12),
                          Text(
                            l10n?.errorKioskDisconnected ??
                                'Kiosk Disconnected from Network',
                            textAlign: TextAlign.center,
                            style: typography.titleMedium.copyWith(
                              color: AppColors.colorError,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          Text(
                            l10n?.errorKioskReconnecting ??
                                'Attempting to reconnect...',
                            textAlign: TextAlign.center,
                            style: typography.bodySmall.copyWith(
                              color: AppColors.colorTextSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          OutlinedButton.icon(
                            onPressed: widget.onRefresh,
                            icon: const Icon(LucideIcons.refreshCw, size: 14),
                            label: Text(l10n?.startupRetry ?? 'Retry'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              if (!isDisconnected) ...[
                // Circular countdown indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: AppColors.colorBorderSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _secondsLeft <= 5
                              ? AppColors.colorError
                              : AppColors.colorActionPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Text(
                      l10n?.kioskSecondsRemaining(_secondsLeft) ??
                          '${_secondsLeft}s',
                      style: typography.titleMedium.copyWith(
                        color: _secondsLeft <= 5
                            ? AppColors.colorError
                            : AppColors.colorTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                // Manual 6-char fallback code
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space24,
                      vertical: AppSpacing.space8),
                  decoration: BoxDecoration(
                    color: AppColors.colorSurfaceBase,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.colorBorderSubtle,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.keyRound,
                          size: 16, color: AppColors.colorTextSecondary),
                      const SizedBox(width: AppSpacing.space8),
                      Text(
                        widget.challenge.displayCode,
                        style: typography.titleLarge.copyWith(
                          color: AppColors.colorActionPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
