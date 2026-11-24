import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailystack/core/theme/app_theme.dart';
import 'package:dailystack/core/widgets/domain_badge.dart';
import 'package:dailystack/core/widgets/state_views.dart';
import 'package:dailystack/features/auth/screens/forgot_password_screen.dart';
import 'package:dailystack/features/auth/screens/login_screen.dart';
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
}
