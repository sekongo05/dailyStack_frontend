import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';

/// Ouvre le quiz diagnostique de 60 secondes (4 questions Backend & DevOps)
/// et retourne le niveau recommandé `1..5` choisi par l'utilisateur.
Future<int?> showLevelPlacementQuizSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LevelPlacementQuizSheet(),
  );
}

class _PlacementQuestion {
  final String badge;
  final String question;
  final List<({String text, bool isCorrect})> options;

  const _PlacementQuestion({
    required this.badge,
    required this.question,
    required this.options,
  });
}

class _LevelPlacementQuizSheet extends StatefulWidget {
  const _LevelPlacementQuizSheet();

  static const List<_PlacementQuestion> _questions = [
    _PlacementQuestion(
      badge: 'Q1 · NIVEAU 1–2 · HTTP & GIT',
      question:
          'Quelle propriété distingue `PUT` de `POST` dans une API REST, et quel est l\'effet d\'un `git rebase main` ?',
      options: [
        (
          text:
              'PUT est idempotent (répéter la requête produit le même état) et rebase rejoue les commits sur la pointe de main.',
          isCorrect: true,
        ),
        (
          text:
              'POST est réservé à la lecture des ressources tandis que PUT chiffre automatiquement le corps JSON.',
          isCorrect: false,
        ),
        (
          text:
              'PUT supprime la ressource distante et git rebase fusionne uniquement les tags de release.',
          isCorrect: false,
        ),
        (
          text: 'Je débute encore sur le protocole HTTP et les branches Git.',
          isCorrect: false,
        ),
      ],
    ),
    _PlacementQuestion(
      badge: 'Q2 · NIVEAU 2–3 · SQL & DOCKER',
      question:
          'Pour accélérer `WHERE status = \'PAID\' ORDER BY created_at DESC LIMIT 20` et livrer une image Java légère, que privilégier ?',
      options: [
        (
          text:
              'Un index composite B-Tree `(status, created_at DESC)` et un Dockerfile multi-stage (build Maven puis JRE slim non-root).',
          isCorrect: true,
        ),
        (
          text:
              'Deux index séparés sur chaque colonne suffisent toujours au tri sans tri mémoire et un conteneur JDK complet root.',
          isCorrect: false,
        ),
        (
          text:
              'Désactiver les clés primaires PostgreSQL et copier tout le dossier `target/` + `.git` dans une seule étape Docker.',
          isCorrect: false,
        ),
        (
          text:
              'Je ne maîtrise pas encore l\'indexation composite ou le multi-stage Docker.',
          isCorrect: false,
        ),
      ],
    ),
    _PlacementQuestion(
      badge: 'Q3 · NIVEAU 3–4 · SPRING & KUBERNETES',
      question:
          'Une méthode `@Transactional` appelle une API externe lente (3 s) dans un pod Kubernetes. Quel incident critique survient sous charge ?',
      options: [
        (
          text:
              'Les connexions HikariCP restent verrouillées pendant l\'appel réseau, épuisant le pool DB ; une `livenessProbe` sur la DB déclencherait en plus des redémarrages en cascade.',
          isCorrect: true,
        ),
        (
          text:
              'Spring libère automatiquement la connexion JDBC pendant l\'attente HTTP et Kubernetes met la transaction en pause.',
          isCorrect: false,
        ),
        (
          text:
              '`@Transactional` annule automatiquement les requêtes HTTP externes en cas d\'erreur 500.',
          isCorrect: false,
        ),
        (
          text:
              'Je n\'ai pas encore travaillé sur HikariCP ou les probes Kubernetes en production.',
          isCorrect: false,
        ),
      ],
    ),
    _PlacementQuestion(
      badge: 'Q4 · NIVEAU 4–5 · ARCHITECTURE DISTRIBUÉE & SLO',
      question:
          'Comment fiabiliser une écriture PostgreSQL + publication Kafka sans 2PC bloquant et migrer une colonne sans interruption de service ?',
      options: [
        (
          text:
              'Pattern Transactional Outbox avec consommateurs idempotents, combiné à une migration Expand / Contract en plusieurs déploiements.',
          isCorrect: true,
        ),
        (
          text:
              'Publier dans Kafka avant le commit SQL suffit toujours, et renommer la colonne directement avec `ALTER TABLE RENAME` pendant le déploiement.',
          isCorrect: false,
        ),
        (
          text:
              'Entourer l\'appel Kafka d\'un `@Async` en mémoire sans table persistante garantit zéro perte en cas de crash du pod.',
          isCorrect: false,
        ),
        (
          text:
              'Ces patterns systèmes distribués et zero-downtime dépassent mon périmètre actuel.',
          isCorrect: false,
        ),
      ],
    ),
  ];

  @override
  State<_LevelPlacementQuizSheet> createState() =>
      _LevelPlacementQuizSheetState();
}

class _LevelPlacementQuizSheetState extends State<_LevelPlacementQuizSheet> {
  final List<int?> _answers = List<int?>.filled(
    _LevelPlacementQuizSheet._questions.length,
    null,
  );
  int _step = 0;
  bool _completed = false;

  int get _correctCount {
    var score = 0;
    for (var i = 0; i < _LevelPlacementQuizSheet._questions.length; i++) {
      final idx = _answers[i];
      if (idx != null &&
          _LevelPlacementQuizSheet._questions[i].options[idx].isCorrect) {
        score++;
      }
    }
    return score;
  }

  int get _recommendedLevel => (_correctCount + 1).clamp(1, 5);

  (String title, String description) _levelFeedback(int level) {
    return switch (level) {
      1 => (
          'Niveau 1 — Amateur',
          'Idéal pour bâtir des bases solides : protocole HTTP, API REST, terminal Linux, Git et premiers schémas SQL sans jargon inutile.',
        ),
      2 => (
          'Niveau 2 — Débutant',
          'Vous connaissez les bases du Web ! Ce palier consolide la conception REST, le modèle relationnel SQL et vos premiers conteneurs Docker.',
        ),
      3 => (
          'Niveau 3 — Junior',
          'Bon socle opérationnel : place aux architectures Spring Boot propres, à l\'indexation PostgreSQL, au CI/CD et à Docker Compose.',
        ),
      4 => (
          'Niveau 4 — Senior',
          'Profil expérimenté : vous attaquerez directement la concurrence, HikariCP, les transactions pièges, Kubernetes et l\'observabilité.',
        ),
      _ => (
          'Niveau 5 — Expert',
          'Maîtrise avancée confirmée : plongez dans les internals distribués (Outbox, consensus, MVCC, multi-région, SLO et haute disponibilité).',
        ),
    };
  }

  void _selectOption(int optionIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      _answers[_step] = optionIndex;
    });
  }

  void _nextStep() {
    if (_step < _LevelPlacementQuizSheet._questions.length - 1) {
      setState(() => _step++);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: _completed
              ? _buildResultView(context)
              : _buildQuestionView(context),
        ),
      ),
    );
  }

  Widget _buildQuestionView(BuildContext context) {
    final total = _LevelPlacementQuizSheet._questions.length;
    final current = _LevelPlacementQuizSheet._questions[_step];
    final selectedIdx = _answers[_step];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const IconTile(
              icon: Icons.psychology_alt_rounded,
              color: AppColors.brand,
              size: 38,
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnostic express (60s)',
                    style: context.text.titleMedium,
                  ),
                  Text(
                    'Question ${_step + 1} sur $total',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fermer',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        ProgressBar(value: (_step + 1) / total, height: 5),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TagPill(
                  label: current.badge,
                  color: AppColors.brand,
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(current.question, style: context.text.titleLarge),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < current.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                    child: SurfaceCard(
                      onTap: () => _selectOption(i),
                      color: selectedIdx == i
                          ? AppColors.brand.withValues(alpha: 0.09)
                          : null,
                      borderColor: selectedIdx == i ? AppColors.brand : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedIdx == i
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 20,
                            color: selectedIdx == i
                                ? AppColors.brand
                                : context.palette.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Text(
                              current.options[i].text,
                              style: context.text.bodyMedium?.copyWith(
                                fontWeight: selectedIdx == i
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (_step > 0) ...[
              OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Retour'),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: PrimaryButton(
                label: _step == total - 1
                    ? 'Calculer mon niveau'
                    : 'Question suivante',
                icon: _step == total - 1
                    ? Icons.auto_awesome_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: selectedIdx != null ? _nextStep : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultView(BuildContext context) {
    final level = _recommendedLevel;
    final (title, description) = _levelFeedback(level);
    final total = _LevelPlacementQuizSheet._questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                borderColor: AppColors.brand.withValues(alpha: 0.40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconTile(
                      icon: Icons.workspace_premium_rounded,
                      color: AppColors.brand,
                      size: 64,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TagPill(
                      label: 'Score : $_correctCount / $total réponses validées',
                      color: AppColors.success,
                      icon: Icons.verified_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Niveau recommandé',
                      style: context.text.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: context.text.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      description,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        PrimaryButton(
          label: 'Choisir le Niveau $level',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(level),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => setState(() {
            _step = 0;
            _completed = false;
          }),
          child: const Text('Recommencer le test'),
        ),
      ],
    );
  }
}
