import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_brand_mark.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/app_feedback.dart';
import '../../../core/design_system/responsive/app_breakpoints.dart';
import '../../../app/localization/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final l10n = AppLocalizations.of(context);
    final isHebrew = ref.read(localeProvider).languageCode == 'he';

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = l10n?.loginValidationEmpty ??
            (isHebrew
                ? 'נא להזין כתובת אימייל וסיסמה.'
                : 'Please enter both your email address and password.');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithPassword(email: email, password: password);
      if (mounted) {
        final redirectParam =
            GoRouterState.of(context).uri.queryParameters['redirect'];
        if (redirectParam != null &&
            redirectParam.isNotEmpty &&
            redirectParam.startsWith('/')) {
          context.go(redirectParam);
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('AuthFailure: ', '');
          _isLoading = false;
        });
        AppFeedback.show(
          context,
          message: _errorMessage!,
          type: AppFeedbackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final isExpanded = AppBreakpoints.isExpanded(context);
    final locale = ref.watch(localeProvider);
    final isHebrew = locale.languageCode == 'he';
    final l10n = AppLocalizations.of(context);

    final titleText = l10n?.loginTitle ??
        (isHebrew ? 'התחברות ל-YellowShifts' : 'Welcome to YellowShifts');
    final subtitleText = l10n?.loginSubtitle ??
        (isHebrew
            ? 'הזן את פרטי ההתחברות כדי לגשת לניהול התחנה שלך.'
            : 'Enter your authorized operational credentials to access station management.');
    final emailLabel =
        l10n?.loginEmailLabel ?? (isHebrew ? 'כתובת אימייל' : 'Email Address');
    final emailHint = l10n?.loginEmailHint ?? 'operator@yellowshifts.com';
    final passwordLabel =
        l10n?.loginPasswordLabel ?? (isHebrew ? 'סיסמה' : 'Password');
    final passwordHint = l10n?.loginPasswordHint ??
        (isHebrew ? 'הזן את סיסמתך' : 'Enter your secure password');
    final buttonLabel = l10n?.loginButton ??
        (isHebrew ? 'התחברות למערכת' : 'Sign In to Operations');
    final heroTitle = l10n?.loginHeroTitle ??
        (isHebrew
            ? 'מהירות תפעולית.\nדיוק רב-תחנתי.'
            : 'Operational Velocity.\nMulti-Station Precision.');
    final heroSubtitle = l10n?.loginHeroSubtitle ??
        (isHebrew
            ? 'מערכת ניהול משמרות וכוח אדם מתקדמת לתחנות, מנהלי משמרת ועובדים בסנכרון מלא בזמן אמת.'
            : 'A modern workforce operations engine designed for stations, shift managers, and field staff with real-time synchronization.');
    final heroBadge = l10n?.loginHeroBadge ??
        (isHebrew
            ? 'מערכת תפעולית • YellowShifts'
            : 'Phase 0 Foundation • Supabase Verified');

    Widget formContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440.0),
        child: Padding(
          padding: AppSpacing.insetAll24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isExpanded) ...[
                const Center(
                  child: AppBrandMark(size: 32.0, showTagline: false),
                ),
                const SizedBox(height: AppSpacing.space24),
              ],
              Text(
                titleText,
                style: typography.titleLarge.copyWith(
                  color: AppColors.colorTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                subtitleText,
                style: typography.bodyMedium.copyWith(
                  color: AppColors.colorTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space24),
              AppTextField(
                label: emailLabel,
                hint: emailHint,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(LucideIcons.mail,
                    size: 18.0, color: AppColors.colorTextMuted),
              ),
              const SizedBox(height: AppSpacing.space16),
              AppTextField(
                label: passwordLabel,
                hint: passwordHint,
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleSignIn(),
                prefixIcon: const Icon(LucideIcons.lock,
                    size: 18.0, color: AppColors.colorTextMuted),
                errorText: _errorMessage,
              ),
              const SizedBox(height: AppSpacing.space24),
              AppButton(
                label: buttonLabel,
                onPressed: _handleSignIn,
                isLoading: _isLoading,
                isFullWidth: true,
                size: AppButtonSize.large,
              ),
              const SizedBox(height: AppSpacing.space24),
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(localeProvider.notifier).toggleLocale(),
                  icon: const Icon(LucideIcons.globe,
                      size: 16.0, color: AppColors.colorTextSecondary),
                  label: Text(
                    isHebrew ? 'English (LTR)' : 'עברית (RTL)',
                    style: typography.labelLarge
                        .copyWith(color: AppColors.colorTextSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!isExpanded) {
      return Scaffold(
        backgroundColor: AppColors.colorSurfaceBase,
        body: SafeArea(child: SingleChildScrollView(child: formContent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              color: AppColors.colorSurfaceBrand,
              padding: AppSpacing.insetAll48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppBrandMark(
                      size: 44.0, showTagline: true, isInverse: false),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heroTitle,
                        style: typography.displayLarge.copyWith(
                          color: AppColors.colorTextPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space16),
                      Text(
                        heroSubtitle,
                        style: typography.bodyLarge.copyWith(
                          color: AppColors.colorTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.space12,
                            vertical: AppSpacing.space6),
                        decoration: const BoxDecoration(
                          color: AppColors.colorSurfaceRaised,
                          borderRadius: AppRadius.borderPill,
                        ),
                        child: Text(
                          heroBadge,
                          style: typography.caption.copyWith(
                            color: AppColors.colorTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: formContent,
          ),
        ],
      ),
    );
  }
}
