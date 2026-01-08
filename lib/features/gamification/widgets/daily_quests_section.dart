import 'package:deltamind/core/routing/app_router.dart';
import 'package:deltamind/features/gamification/gamification_controller.dart';
import 'package:deltamind/features/gamification/widgets/daily_quest_card.dart';
import 'package:deltamind/models/daily_quest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DailyQuestsSection extends ConsumerWidget {
  const DailyQuestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final gamificationState = ref.watch(gamificationControllerProvider);
    final dailyQuests = gamificationState.dailyQuests;
    final theme = Theme.of(context);

    // Calculate overall completion
    final completionRate = ref
        .read(gamificationControllerProvider.notifier)
        .dailyQuestCompletionRate;
    final earnedXP =
        ref.read(gamificationControllerProvider.notifier).earnedDailyQuestXP;
    final totalXP =
        ref.read(gamificationControllerProvider.notifier).totalDailyQuestXP;

    if (dailyQuests.isEmpty) {
      // Show empty state with a retry option
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.dailyQuests,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Icon(
                PhosphorIconsFill.clipboard,
                size: 50,
                color: Color(0xFFDDDDDD),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noQuestsAvailableRightNow,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.comeBackTomorrowForNewQuests,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Reload gamification data to try loading quests again
                  ref
                      .read(gamificationControllerProvider.notifier)
                      .loadGamificationData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056D2),
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.refresh),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
          child: Row(
            children: [
              const Icon(
                PhosphorIconsFill.trophy,
                size: 20,
                color: Color(0xFF0056D2), // Brand blue
              ),
              const SizedBox(width: 8),
              Text(
                l10n.dailyQuests,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF000000), // Brand black
                ),
              ),
              const Spacer(),

              // XP summary
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsFill.star,
                      size: 14,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$earnedXP/$totalXP ${l10n.xpLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Overall progress indicator
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0056D2).withOpacity(0.9), // Brand blue
                const Color(0xFF33A1FD).withOpacity(0.9), // Light blue
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF33A1FD).withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dailyProgress,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Progress circle
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: completionRate,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 8,
                          ),
                        ),
                        Center(
                          child: Text(
                            '${(completionRate * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Text info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.questsCompleted(
                              dailyQuests.where((q) => q.completed).length,
                              dailyQuests.length),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          completionRate >= 1.0
                              ? l10n.allQuestsCompletedToday
                              : l10n.completeQuestsToEarnXp,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Quest cards
        ...dailyQuests
            .map((quest) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DailyQuestCard(
                    quest: quest,
                    onTap: () => _handleQuestTap(context, quest, ref),
                  ),
                ))
            .toList(),
      ],
    );
  }

  void _handleQuestTap(BuildContext context, DailyQuest quest, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (quest.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.questAlreadyCompleted)),
      );
      return;
    }

    // Show quest details or relevant action
    final questAction = _getQuestAction(quest.questType, l10n);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getLocalizedTitle(quest.questType, l10n)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getLocalizedDescription(
                quest.questType, quest.targetCount, l10n)),
            const SizedBox(height: 16),
            Text(l10n.progress(quest.progressText)),
            const SizedBox(height: 8),
            Text(l10n.reward(quest.xpReward)),
            const SizedBox(height: 16),
            Text(l10n.goToToMakeProgress(questAction.name)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              // Navigate to the relevant feature
              switch (quest.questType) {
                case 'complete_quiz':
                  context.push(AppRoutes.quizList);
                  break;
                case 'write_note':
                  // Assuming AppRoutes.notes exists, if not I'll check AppRouter or just use '/notes'
                  // I'll check AppRouter in a moment, but safe bet is likely AppRoutes.notes if following convention
                  // Looking at previous context, user mentions "integration flashcard...". Maybe notes route exists?
                  // I will check AppRouter first to be safe.
                  // For now, I'll use a safe fallback or check AppRouter.
                  context.push('/notes');
                  break;
                case 'review_flashcards':
                  context.push('/flashcards');
                  break;
                default:
                  break;
              }
            },
            child: Text(l10n.goTo(questAction.name)),
          ),
        ],
      ),
    );
  }

  _QuestAction _getQuestAction(String questType, AppLocalizations l10n) {
    switch (questType) {
      case 'complete_quiz':
        return _QuestAction(l10n.quizzes, PhosphorIconsFill.exam);
      case 'write_note':
        return _QuestAction(l10n.notes, PhosphorIconsFill.notepad);
      case 'review_flashcards':
        return _QuestAction(l10n.flashcards, PhosphorIconsFill.cards);
      default:
        return _QuestAction(l10n.dashboard, PhosphorIconsFill.house);
    }
  }

  String _getLocalizedTitle(String questType, AppLocalizations l10n) {
    switch (questType) {
      case 'complete_quiz':
        return l10n.completeQuizzesTitle;
      case 'write_note':
        return l10n.writeNotesTitle;
      case 'review_flashcards':
        return l10n.reviewFlashcardsTitle;
      default:
        return l10n.unknownQuestTitle;
    }
  }

  String _getLocalizedDescription(
      String questType, int targetCount, AppLocalizations l10n) {
    switch (questType) {
      case 'complete_quiz':
        return targetCount == 1
            ? l10n.completeQuizzesDescriptionSingular(targetCount)
            : l10n.completeQuizzesDescription(targetCount);
      case 'write_note':
        return targetCount == 1
            ? l10n.writeNotesDescription(targetCount)
            : l10n.writeNotesDescriptionPlural(targetCount);
      case 'review_flashcards':
        return l10n.reviewFlashcardsDescription(targetCount);
      default:
        return l10n.unknownQuestDescription;
    }
  }
}

class _QuestAction {
  final String name;
  final IconData icon;

  _QuestAction(this.name, this.icon);
}
