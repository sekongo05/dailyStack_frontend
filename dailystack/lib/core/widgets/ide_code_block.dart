import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Bloc de code style IDE / Terminal sombre avec coloration syntaxique légère
/// et bouton de copie interactif.
class IdeCodeBlock extends StatefulWidget {
  final String code;
  final String? language;
  final EdgeInsetsGeometry margin;

  const IdeCodeBlock({
    super.key,
    required this.code,
    this.language,
    this.margin = const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  });

  /// Détecte la langue d'un extrait de code si aucune étiquette explicite n'est fournie.
  static String inferLanguage(String rawCode, [String? explicitLanguage]) {
    if (explicitLanguage != null && explicitLanguage.trim().isNotEmpty) {
      return explicitLanguage.trim().toUpperCase();
    }
    final sample = rawCode.trim();
    if (sample.isEmpty) return 'CODE';

    if (RegExp(r'^(FROM|WORKDIR|ENTRYPOINT)\b', multiLine: true)
            .hasMatch(sample) &&
        RegExp(r'\b(RUN|COPY|EXPOSE|CMD)\b').hasMatch(sample)) {
      return 'DOCKERFILE';
    }
    if (RegExp(
      r'(@Transactional|@RestController|@Service|@Entity|public\s+class|public\s+record|private\s+final|System\.out)',
    ).hasMatch(sample)) {
      return 'JAVA';
    }
    if (RegExp(
      r'\b(SELECT|INSERT\s+INTO|UPDATE\s+\w+\s+SET|CREATE\s+(UNIQUE\s+)?INDEX|CREATE\s+TABLE|EXPLAIN\s+ANALYZE)\b',
      caseSensitive: false,
    ).hasMatch(sample)) {
      return 'SQL';
    }
    if (RegExp(
      r'^(apiVersion:|kind:|services:|replicas:|livenessProbe:|readinessProbe:|spring:)',
      multiLine: true,
    ).hasMatch(sample)) {
      return 'YAML';
    }
    if ((sample.startsWith('{') && sample.endsWith('}')) ||
        (sample.startsWith('[') &&
            sample.endsWith(']') &&
            sample.contains('":'))) {
      return 'JSON';
    }
    if (RegExp(
      r'(^#!/bin/|\b(kubectl|docker|curl|git|mvn|chmod|systemctl|grep|awk)\b)',
      multiLine: true,
    ).hasMatch(sample)) {
      return 'BASH';
    }
    if (RegExp(r'^(GET|POST|PUT|PATCH|DELETE)\s+/\S*\s*HTTP', multiLine: true)
        .hasMatch(sample)) {
      return 'HTTP';
    }
    return 'CODE';
  }

  /// Extrait le code propre et la langue éventuelle si `raw` contient des balises ```lang.
  static (String cleanCode, String? fenceLang) stripOuterFence(String raw) {
    final trimmed = raw.trimRight();
    if (!trimmed.trimLeft().startsWith('```')) {
      return (trimmed, null);
    }
    final lines = trimmed.trimLeft().split('\n');
    if (lines.length < 2) return (trimmed, null);
    final firstLine = lines.first.trim();
    final lang = firstLine.substring(3).trim();
    final bodyLines = lines.sublist(1);
    if (bodyLines.isNotEmpty && bodyLines.last.trim() == '```') {
      bodyLines.removeLast();
    }
    return (
      bodyLines.join('\n').trimRight(),
      lang.isEmpty ? null : lang,
    );
  }

  @override
  State<IdeCodeBlock> createState() => _IdeCodeBlockState();
}

class _IdeCodeBlockState extends State<IdeCodeBlock> {
  static final RegExp _tokenRegex = RegExp(
    r'(?<comment>//[^\n]*|#[^\n]*)'
    r'|(?<string>"(?:\\.|[^"\\])*"|'
    r"'(?:\\.|[^'\\])*')"
    r'|(?<annotation>@[A-Za-z_][A-Za-z0-9_]*)'
    r'|(?<keyword>\b(?:public|private|protected|class|interface|record|enum|extends|implements|return|if|else|for|while|switch|case|try|catch|finally|throw|throws|new|void|static|final|synchronized|volatile|async|await|import|package|var|val|const|true|false|null|boolean|int|long|double|String|List|Map|Optional|SELECT|FROM|WHERE|AND|OR|NOT|IN|IS|NULL|JOIN|LEFT|RIGHT|INNER|ON|GROUP|BY|ORDER|ASC|DESC|LIMIT|OFFSET|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|ALTER|DROP|TABLE|UNIQUE|INDEX|CONCURRENTLY|EXPLAIN|ANALYZE|BEGIN|COMMIT|ROLLBACK|PRIMARY|KEY|FOREIGN|REFERENCES|RUN|COPY|ADD|WORKDIR|EXPOSE|ENTRYPOINT|CMD|ENV|ARG|USER|HEALTHCHECK|AS|apiVersion|kind|metadata|spec|replicas|containers|ports|livenessProbe|readinessProbe|startupProbe|resources|limits|requests|services|image|volumes|environment|depends_on)\b)'
    r'|(?<number>\b\d+(?:\.\d+)?\b)',
    multiLine: true,
  );

  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copyCode(String cleanCode) {
    Clipboard.setData(ClipboardData(text: cleanCode));
    HapticFeedback.lightImpact();
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  List<TextSpan> _highlightCode(String source, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in _tokenRegex.allMatches(source)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (match.namedGroup('comment') != null) {
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(
              color: const Color(0xFF64748B),
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (match.namedGroup('string') != null) {
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(color: const Color(0xFF34D399)),
          ),
        );
      } else if (match.namedGroup('annotation') != null) {
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(
              color: const Color(0xFFFBBF24),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (match.namedGroup('keyword') != null) {
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(
              color: const Color(0xFF38BDF8),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (match.namedGroup('number') != null) {
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(color: const Color(0xFFC084FC)),
          ),
        );
      } else {
        spans.add(TextSpan(text: token));
      }
      cursor = match.end;
    }

    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final (cleanCode, fenceLang) = IdeCodeBlock.stripOuterFence(widget.code);
    if (cleanCode.isEmpty) return const SizedBox.shrink();

    final langBadge = IdeCodeBlock.inferLanguage(
      cleanCode,
      widget.language ?? fenceLang,
    );

    final monoStyle = GoogleFonts.jetBrainsMono(
      fontSize: 13,
      height: 1.55,
      color: const Color(0xFFE2E8F0),
    );

    return Container(
      width: double.infinity,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: Row(
              children: [
                const _MacDot(color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                const _MacDot(color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                const _MacDot(color: Color(0xFF10B981)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    langBadge,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _copyCode(cleanCode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied
                                ? Icons.check_rounded
                                : Icons.copy_rounded,
                            size: 14,
                            color: _copied
                                ? AppColors.success
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _copied ? 'Copié ✓' : 'Copier',
                            style: context.text.labelSmall?.copyWith(
                              color: _copied
                                  ? AppColors.success
                                  : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText.rich(
              TextSpan(
                style: monoStyle,
                children: _highlightCode(cleanCode, monoStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacDot extends StatelessWidget {
  final Color color;
  const _MacDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.78),
        shape: BoxShape.circle,
      ),
    );
  }
}
