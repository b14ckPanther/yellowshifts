import 'package:flutter/widgets.dart';

/// Semantic responsive size classes for YellowShifts.
enum AppSizeClass {
  compact, // < 600px (Mobile Phones)
  medium, // 600px - 1024px (Tablets & Foldables)
  expanded // > 1024px (Desktop & Wide Web)
}

abstract class AppBreakpoints {
  static const double compactMaxWidth = 600.0;
  static const double mediumMaxWidth = 1024.0;

  static AppSizeClass sizeClassOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactMaxWidth) {
      return AppSizeClass.compact;
    } else if (width <= mediumMaxWidth) {
      return AppSizeClass.medium;
    } else {
      return AppSizeClass.expanded;
    }
  }

  static bool isCompact(BuildContext context) =>
      sizeClassOf(context) == AppSizeClass.compact;
  static bool isMedium(BuildContext context) =>
      sizeClassOf(context) == AppSizeClass.medium;
  static bool isExpanded(BuildContext context) =>
      sizeClassOf(context) == AppSizeClass.expanded;
}

/// Helper to select values based on current screen size class.
class ResponsiveValue<T> {
  final T compact;
  final T? medium;
  final T? expanded;

  const ResponsiveValue({
    required this.compact,
    this.medium,
    this.expanded,
  });

  T resolve(BuildContext context) {
    final sizeClass = AppBreakpoints.sizeClassOf(context);
    switch (sizeClass) {
      case AppSizeClass.compact:
        return compact;
      case AppSizeClass.medium:
        return medium ?? compact;
      case AppSizeClass.expanded:
        return expanded ?? medium ?? compact;
    }
  }
}

/// Widget builder that adapts its child to the active AppSizeClass.
class AdaptiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, AppSizeClass sizeClass) builder;

  const AdaptiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final sizeClass = AppBreakpoints.sizeClassOf(context);
    return builder(context, sizeClass);
  }
}
