import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/theme/app_responsive.dart';

Widget _withSize(Size size, Widget child) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: child,
  ),
);

void main() {
  group('AppResponsive.sizeClass', () {
    testWidgets('returns xs for width 375', (tester) async {
      late SizeClass result;
      await tester.pumpWidget(
        _withSize(
          const Size(375, 812),
          Builder(
            builder: (context) {
              result = AppResponsive.sizeClass(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, SizeClass.xs);
    });

    testWidgets('returns sm for width 520', (tester) async {
      late SizeClass result;
      await tester.pumpWidget(
        _withSize(
          const Size(520, 900),
          Builder(
            builder: (context) {
              result = AppResponsive.sizeClass(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, SizeClass.sm);
    });

    testWidgets('returns md for width 800', (tester) async {
      late SizeClass result;
      await tester.pumpWidget(
        _withSize(
          const Size(800, 1024),
          Builder(
            builder: (context) {
              result = AppResponsive.sizeClass(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, SizeClass.md);
    });

    testWidgets('returns lg for width 1200', (tester) async {
      late SizeClass result;
      await tester.pumpWidget(
        _withSize(
          const Size(1200, 800),
          Builder(
            builder: (context) {
              result = AppResponsive.sizeClass(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, SizeClass.lg);
    });
  });

  group('AppResponsive tokens', () {
    testWidgets('spriteScale returns 4.0 for xs', (tester) async {
      late double result;
      await tester.pumpWidget(
        _withSize(
          const Size(375, 812),
          Builder(
            builder: (context) {
              result = AppResponsive.spriteScale(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, 4.0);
    });

    testWidgets('gridMaxExtent returns 240 for md', (tester) async {
      late double result;
      await tester.pumpWidget(
        _withSize(
          const Size(800, 1024),
          Builder(
            builder: (context) {
              result = AppResponsive.gridMaxExtent(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, 240.0);
    });

    testWidgets('buttonSize returns 44 for xs', (tester) async {
      late double result;
      await tester.pumpWidget(
        _withSize(
          const Size(375, 812),
          Builder(
            builder: (context) {
              result = AppResponsive.buttonSize(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, 44.0);
    });

    testWidgets('isCompact true for xs', (tester) async {
      late bool result;
      await tester.pumpWidget(
        _withSize(
          const Size(375, 812),
          Builder(
            builder: (context) {
              result = AppResponsive.isCompact(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, isTrue);
    });

    testWidgets('isCompact false for md', (tester) async {
      late bool result;
      await tester.pumpWidget(
        _withSize(
          const Size(800, 1024),
          Builder(
            builder: (context) {
              result = AppResponsive.isCompact(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, isFalse);
    });

    testWidgets('isTablet backward compat returns !isCompact', (tester) async {
      late bool isTablet;
      late bool isCompact;
      await tester.pumpWidget(
        _withSize(
          const Size(800, 1024),
          Builder(
            builder: (context) {
              isTablet = AppResponsive.isTablet(context);
              isCompact = AppResponsive.isCompact(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isTablet, equals(!isCompact));
    });
  });
}
