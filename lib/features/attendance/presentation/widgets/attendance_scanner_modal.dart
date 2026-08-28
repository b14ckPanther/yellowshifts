import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

class AttendanceScannerModal extends StatefulWidget {
  final Function(String code) onCodeDetected;

  const AttendanceScannerModal({
    super.key,
    required this.onCodeDetected,
  });

  @override
  State<AttendanceScannerModal> createState() => _AttendanceScannerModalState();
}

class _AttendanceScannerModalState extends State<AttendanceScannerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _manualCodeController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualCodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        setState(() {
          _hasScanned = true;
        });
        widget.onCodeDetected(rawValue.trim());
        Navigator.of(context).pop();
        break;
      }
    }
  }

  void _submitManualCode() {
    final code = _manualCodeController.text.trim();
    if (code.length >= 4) {
      widget.onCodeDetected(code);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.space16),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.colorBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.colorSurfaceBrand,
            labelColor: AppColors.colorTextPrimary,
            unselectedLabelColor: AppColors.colorTextSecondary,
            tabs: [
              Tab(
                  icon: const Icon(LucideIcons.camera),
                  text: l10n.scannerTabCamera),
              Tab(
                  icon: const Icon(LucideIcons.keyboard),
                  text: l10n.scannerTabManual),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Camera Scanner View
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                        errorBuilder: (context, error, child) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.space24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.cameraOff,
                                      size: 48, color: AppColors.colorWarning),
                                  const SizedBox(height: AppSpacing.space16),
                                  Text(
                                    l10n.scannerCameraUnavailable,
                                    style: typography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.colorTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space8),
                                  Text(
                                    l10n.scannerCameraPermError,
                                    textAlign: TextAlign.center,
                                    style: typography.caption.copyWith(
                                      color: AppColors.colorTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Target bounding box overlay
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.colorSurfaceBrand, width: 3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                ),
                // Manual Code Entry View
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.space24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(LucideIcons.keyRound,
                          size: 48, color: AppColors.colorSurfaceBrand),
                      const SizedBox(height: AppSpacing.space16),
                      Text(
                        l10n.scannerEnterKioskCode,
                        textAlign: TextAlign.center,
                        style: typography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.colorTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space8),
                      Text(
                        l10n.scannerEnterCodeDesc,
                        textAlign: TextAlign.center,
                        style: typography.bodyMedium.copyWith(
                          color: AppColors.colorTextSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space24),
                      TextField(
                        controller: _manualCodeController,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: typography.displayLarge.copyWith(
                          letterSpacing: 6.0,
                          fontWeight: FontWeight.bold,
                          color: AppColors.colorTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ABC123',
                          filled: true,
                          fillColor: AppColors.colorSurfaceBase,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.colorBorderSubtle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submitManualCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.colorSurfaceBrand,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            l10n.scannerVerifyCodeAction,
                            style: typography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
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
