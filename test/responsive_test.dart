import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/design_system/responsive/app_breakpoints.dart';

void main() {
  group('Responsive Breakpoints', () {
    testWidgets('Resolves AppSizeClass.compact for widths < 600px',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AdaptiveBuilder(
              builder: _testBuilder,
            ),
          ),
        ),
      );

      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets('Resolves AppSizeClass.medium for widths 600px - 1024px',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(768, 1024)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AdaptiveBuilder(
              builder: _testBuilder,
            ),
          ),
        ),
      );

      expect(find.text('medium'), findsOneWidget);
    });

    testWidgets('Resolves AppSizeClass.expanded for widths > 1024px',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(1440, 900)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AdaptiveBuilder(
              builder: _testBuilder,
            ),
          ),
        ),
      );

      expect(find.text('expanded'), findsOneWidget);
    });
  });
}

Widget _testBuilder(BuildContext context, AppSizeClass sizeClass) {
  return Text(sizeClass.name);
}
