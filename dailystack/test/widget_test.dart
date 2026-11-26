import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailystack/core/theme/app_theme.dart';
import 'package:dailystack/core/widgets/domain_badge.dart';
import 'package:dailystack/core/widgets/ide_code_block.dart';
import 'package:dailystack/core/widgets/state_views.dart';
import 'package:dailystack/core/widgets/ui.dart';
import 'package:dailystack/features/auth/screens/forgot_password_screen.dart';
import 'package:dailystack/features/auth/screens/login_screen.dart';
import 'package:dailystack/features/auth/screens/register_screen.dart';
import 'package:dailystack/features/practice/models/practice_models.dart';
import 'package:dailystack/features/practice/widgets/mastery_badge.dart';
import 'package:dailystack/main.dart';

void main() {
  testWidgets('DailyStackApp renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DailyStackApp()));
    expect(find.text('DailyStack'), findsOneWidget);
  });

  testWidgets('DomainBadge renders icon and text for Backend and DevOps', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DomainBadge(domainCode: 'BACKEND'),
              DomainBadge(domainCode: 'DEVOPS'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('DevOps'), findsOneWidget);
    expect(find.byIcon(Icons.dns_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cloud_sync_rounded), findsOneWidget);
  });

  testWidgets('MasteryBadge uses encouraging vocabulary', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MasteryBadge(level: MasteryLevel.DISCOVERY),
              MasteryBadge(level: MasteryLevel.IN_PROGRESS),
              MasteryBadge(level: MasteryLevel.MASTERED),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Découverte'), findsOneWidget);
    expect(find.text('À consolider'), findsOneWidget);
    expect(find.text('Maîtrisée'), findsOneWidget);
  });

  testWidgets('OfflineBanner displays pending sync message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OfflineBanner(pendingSync: true),
        ),
      ),
    );

    expect(
      find.text('Données stockées localement - en attente de synchronisation'),
      findsOneWidget,
    );
  });

  testWidgets('AppErrorView hides technical exception details', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppErrorView(
            message: "FormatException: Unexpected character (at character 1)",
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('FormatException'), findsNothing);
    expect(
      find.text('Une erreur technique est survenue. Veuillez réessayer plus tard.'),
      findsOneWidget,
    );
  });

  testWidgets('HomeSkeletonView renders loading placeholders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: HomeSkeletonView(),
        ),
      ),
    );

    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('LoginScreen displays forgot password action', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
  });

  testWidgets('ForgotPasswordScreen renders email request step', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ForgotPasswordScreen(),
        ),
      ),
    );

    expect(find.text('Envoyer le code'), findsOneWidget);
  });

  testWidgets('IdeCodeBlock renders uppercase language badge, copy button, and code', (WidgetTester tester) async {
    const snippet = '''
@Transactional
public void processOrder(Long id) {
  return;
}''';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: IdeCodeBlock(
            code: snippet,
            language: 'java',
          ),
        ),
      ),
    );

    expect(find.text('JAVA'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
    expect(
      find.textContaining('@Transactional', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('RegisterScreen displays 60s placement quiz CTA', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RegisterScreen(),
        ),
      ),
    );

    expect(
      find.text('Pas sûr ? Tester mon niveau en 60s'),
      findsOneWidget,
    );
  });

  testWidgets('UI renders cleanly without overflow at 320px and 1024px', (WidgetTester tester) async {
    const viewports = [Size(320, 568), Size(375, 812), Size(1024, 768)];

    for (final size in viewports) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.2),
              ),
              child: const RegisterScreen(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.2),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      title: 'Tableau de bord',
                      subtitle: 'Progression quotidienne Backend & DevOps',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.streak,
                            value: '365 j',
                            label: 'Série active',
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(
                            icon: Icons.verified_rounded,
                            color: AppColors.success,
                            value: '142',
                            label: 'Notions maîtrisées',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md),
                    TagPill(
                      label: 'Architecture distribuée & Tolérance aux pannes avancée',
                      color: AppColors.brand,
                      icon: Icons.bolt_rounded,
                    ),
                    SizedBox(height: AppSpacing.md),
                    OfflineBanner(pendingSync: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
