import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

/// A card showing summary analytics info with modern design
class SummaryCard extends StatelessWidget {
  final QuizAnalytics analytics;

  const SummaryCard({Key? key, required this.analytics}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 1);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              AppColors.primary.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsFill.chartLine,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.performanceOverview,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (analytics.lastUpdated != null)
                  Text(
                    '${l10n.updated}${_formatUpdateTime(analytics.lastUpdated!, l10n)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),

            // Average score with circular indicator
            Row(
              children: [
                _buildScoreIndicator(context, analytics.averageScore, l10n),
                const SizedBox(width: 16),
                Expanded(child: _buildStatsList(context, l10n)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(
      BuildContext context, double score, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final size = 100.0;

    // Determine color based on score
    Color scoreColor = AppColors.primary;
    if (score < 40) {
      scoreColor = AppColors.error;
    } else if (score < 70) {
      scoreColor = AppColors.warning;
    } else if (score >= 90) {
      scoreColor = AppColors.success;
    }

    return Container(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 10,
              backgroundColor: scoreColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.toStringAsFixed(1)}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              Text(
                l10n.average,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsList(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatItem(
          context,
          l10n.quizzesCompleted,
          '${analytics.totalAttempts}',
          PhosphorIconsFill.checkSquare,
        ),
        const SizedBox(height: 16),
        _buildStatItem(
          context,
          l10n.questionsAnswered,
          '${analytics.totalQuestionsAttempted}',
          PhosphorIconsFill.listChecks,
        ),
        const SizedBox(height: 16),
        _buildStatItem(
          context,
          l10n.correctAnswers,
          '${analytics.totalCorrectAnswers}',
          PhosphorIconsFill.check,
          additionalInfo: analytics.totalQuestionsAttempted > 0
              ? '${(analytics.totalCorrectAnswers / analytics.totalQuestionsAttempted * 100).toStringAsFixed(1)}% ${l10n.accuracy}'
              : null,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    String? additionalInfo,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (additionalInfo != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        additionalInfo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.7),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatUpdateTime(DateTime dateTime, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return l10n.daysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.hoursAgo(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return l10n.minutesAgo(difference.inMinutes);
    } else {
      return l10n.justNow;
    }
  }
}
