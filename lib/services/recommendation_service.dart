import 'package:deltamind/services/gemini_service.dart';
import 'package:deltamind/services/supabase_service.dart';
import 'package:flutter/foundation.dart';

/// Service for AI recommendations
class RecommendationService {
  /// Get an AI recommendation for a quiz attempt
  /// If a recommendation already exists, return it
  /// Otherwise, generate a new one
  /// [language] is the language to generate/translate content in (e.g., "Vietnamese", "English"). If null, defaults to English.
  static Future<Map<String, dynamic>?> getQuizRecommendation(
    String quizAttemptId, {
    String? language,
  }) async {
    try {
      // Check if a recommendation already exists
      final existingRecommendation = await SupabaseService.client
          .from('ai_recommendations')
          .select()
          .eq('quiz_attempt_id', quizAttemptId)
          .maybeSingle();

      if (existingRecommendation != null) {
        // If language is specified and not English, translate existing recommendation
        if (language != null &&
            language.isNotEmpty &&
            language.toLowerCase() != 'english') {
          debugPrint('Translating existing recommendation to $language...');
          return await _translateExistingRecommendation(
              existingRecommendation, language);
        }
        return existingRecommendation;
      }

      // No existing recommendation, so generate a new one
      return await generateAndSaveQuizRecommendation(quizAttemptId,
          language: language);
    } catch (e) {
      debugPrint('Error getting quiz recommendation: $e');
      return null;
    }
  }

  /// Translate an existing recommendation to target language
  static Future<Map<String, dynamic>> _translateExistingRecommendation(
    Map<String, dynamic> recommendation,
    String targetLanguage,
  ) async {
    try {
      final translatedRecommendation =
          Map<String, dynamic>.from(recommendation);

      // Get the main fields to translate (prefer new field names, fallback to old)
      final performanceOverview = recommendation['performance_overview'] ??
          recommendation['overall_assessment'];
      final strengths =
          recommendation['strengths'] ?? recommendation['strong_areas'];
      final areasForImprovement = recommendation['areas_for_improvement'] ??
          recommendation['weak_areas'];
      final learningStrategies = recommendation['learning_strategies'] ??
          recommendation['learning_recommendations'];
      final actionPlan =
          recommendation['action_plan'] ?? recommendation['next_steps'];
      final studyResources = recommendation['study_resources'];

      debugPrint(
          '=== Translating existing recommendation to $targetLanguage (batch) ===');

      // Collect all fields to translate in a map
      final textsToTranslate = <String, String>{};

      if (performanceOverview != null &&
          performanceOverview.toString().trim().isNotEmpty) {
        textsToTranslate['performance_overview'] =
            performanceOverview.toString();
      }

      if (strengths != null && strengths.toString().trim().isNotEmpty) {
        textsToTranslate['strengths'] = strengths.toString();
      }

      if (areasForImprovement != null &&
          areasForImprovement.toString().trim().isNotEmpty) {
        textsToTranslate['areas_for_improvement'] =
            areasForImprovement.toString();
      }

      if (learningStrategies != null &&
          learningStrategies.toString().trim().isNotEmpty) {
        textsToTranslate['learning_strategies'] = learningStrategies.toString();
      }

      if (actionPlan != null && actionPlan.toString().trim().isNotEmpty) {
        textsToTranslate['action_plan'] = actionPlan.toString();
      }

      if (studyResources != null &&
          studyResources.toString().trim().isNotEmpty) {
        textsToTranslate['study_resources'] = studyResources.toString();
      }

      // Translate all fields in one batch request
      if (textsToTranslate.isNotEmpty) {
        try {
          final translatedMap =
              await GeminiService.translateMultipleTextsPreservingFormat(
            texts: textsToTranslate,
            targetLanguage: targetLanguage,
          );

          // Update translated recommendations
          for (final entry in translatedMap.entries) {
            translatedRecommendation[entry.key] = entry.value;

            // Also update backward compatibility fields
            if (entry.key == 'performance_overview') {
              translatedRecommendation['overall_assessment'] = entry.value;
            } else if (entry.key == 'strengths') {
              translatedRecommendation['strong_areas'] = entry.value;
            } else if (entry.key == 'areas_for_improvement') {
              translatedRecommendation['weak_areas'] = entry.value;
            } else if (entry.key == 'learning_strategies') {
              translatedRecommendation['learning_recommendations'] =
                  entry.value;
            } else if (entry.key == 'action_plan') {
              translatedRecommendation['next_steps'] = entry.value;
            }
          }

          debugPrint(
              'Batch translation completed (${translatedMap.length} fields)');
        } catch (e) {
          debugPrint(
              'Error in batch translation, falling back to parallel: $e');
          // Fallback to parallel translation if batch fails
          final translationFutures = <String, Future<String>>{};
          for (final entry in textsToTranslate.entries) {
            translationFutures[entry.key] =
                GeminiService.translateTextPreservingFormat(
              text: entry.value,
              targetLanguage: targetLanguage,
            );
          }

          final translationResults = await Future.wait(
            translationFutures.entries.map((entry) async {
              try {
                final translated = await entry.value;
                return MapEntry(entry.key, translated);
              } catch (e) {
                debugPrint('Error translating ${entry.key}: $e');
                return MapEntry(entry.key, textsToTranslate[entry.key] ?? '');
              }
            }),
          );

          for (final entry in translationResults) {
            translatedRecommendation[entry.key] = entry.value;
            if (entry.key == 'performance_overview') {
              translatedRecommendation['overall_assessment'] = entry.value;
            } else if (entry.key == 'strengths') {
              translatedRecommendation['strong_areas'] = entry.value;
            } else if (entry.key == 'areas_for_improvement') {
              translatedRecommendation['weak_areas'] = entry.value;
            } else if (entry.key == 'learning_strategies') {
              translatedRecommendation['learning_recommendations'] =
                  entry.value;
            } else if (entry.key == 'action_plan') {
              translatedRecommendation['next_steps'] = entry.value;
            }
          }
        }
      }

      // Update the database with translated content
      await SupabaseService.client.from('ai_recommendations').update({
        'performance_overview':
            translatedRecommendation['performance_overview'],
        'strengths': translatedRecommendation['strengths'],
        'areas_for_improvement':
            translatedRecommendation['areas_for_improvement'],
        'learning_strategies': translatedRecommendation['learning_strategies'],
        'action_plan': translatedRecommendation['action_plan'],
        // Backward compatibility
        'overall_assessment': translatedRecommendation['performance_overview'],
        'weak_areas': translatedRecommendation['areas_for_improvement'],
        'strong_areas': translatedRecommendation['strengths'],
        'learning_recommendations':
            translatedRecommendation['learning_strategies'],
        'next_steps': translatedRecommendation['action_plan'],
      }).eq('quiz_attempt_id', recommendation['quiz_attempt_id']);

      debugPrint('Translation and update completed for $targetLanguage');
      return translatedRecommendation;
    } catch (e) {
      debugPrint('Error translating existing recommendation: $e');
      // Return original if translation fails
      return recommendation;
    }
  }

  /// Generate and save a new AI recommendation for a quiz attempt
  /// [language] is the language to generate content in (e.g., "Vietnamese", "English"). If null, defaults to English.
  static Future<Map<String, dynamic>?> generateAndSaveQuizRecommendation(
    String quizAttemptId, {
    String? language,
  }) async {
    try {
      // Get quiz attempt with quiz details
      final quizAttempt =
          await SupabaseService.client.from('quiz_attempts').select('''
            id,
            score,
            total_questions,
            time_taken,
            created_at,
            quizzes (
              id,
              title,
              description,
              quiz_type,
              difficulty
            )
          ''').eq('id', quizAttemptId).single();

      // Get user answers with question details
      final userAnswers =
          await SupabaseService.client.from('user_answers').select('''
            id,
            user_answer,
            is_correct,
            time_taken,
            questions (
              id,
              question_text,
              question_type,
              options,
              correct_answer,
              explanation
            )
          ''').eq('quiz_attempt_id', quizAttemptId).order('created_at');

      // Call Gemini to generate recommendations (always in English first)
      // We'll translate afterwards if needed
      final recommendations = await GeminiService.generateQuizRecommendations(
        quizData: quizAttempt,
        userAnswers: List<Map<String, dynamic>>.from(userAnswers),
        language: null, // Always generate in English first
      );

      // If language is specified and not English, translate all fields
      Map<String, dynamic> translatedRecommendations =
          Map<String, dynamic>.from(recommendations);
      debugPrint('Language parameter: $language');
      if (language != null &&
          language.isNotEmpty &&
          language.toLowerCase() != 'english') {
        debugPrint('=== Translating recommendations to $language (batch) ===');

        // Get the main fields to translate (prefer new field names, fallback to old)
        final performanceOverview = recommendations['performance_overview'] ??
            recommendations['overall_assessment'];
        final strengths =
            recommendations['strengths'] ?? recommendations['strong_areas'];
        final areasForImprovement = recommendations['areas_for_improvement'] ??
            recommendations['weak_areas'];
        final learningStrategies = recommendations['learning_strategies'] ??
            recommendations['learning_recommendations'];
        final actionPlan =
            recommendations['action_plan'] ?? recommendations['next_steps'];
        final studyResources = recommendations['study_resources'];

        // Collect all fields to translate in a map
        final textsToTranslate = <String, String>{};

        if (performanceOverview != null &&
            performanceOverview.toString().trim().isNotEmpty) {
          textsToTranslate['performance_overview'] =
              performanceOverview.toString();
        }

        if (strengths != null && strengths.toString().trim().isNotEmpty) {
          textsToTranslate['strengths'] = strengths.toString();
        }

        if (areasForImprovement != null &&
            areasForImprovement.toString().trim().isNotEmpty) {
          textsToTranslate['areas_for_improvement'] =
              areasForImprovement.toString();
        }

        if (learningStrategies != null &&
            learningStrategies.toString().trim().isNotEmpty) {
          textsToTranslate['learning_strategies'] =
              learningStrategies.toString();
        }

        if (actionPlan != null && actionPlan.toString().trim().isNotEmpty) {
          textsToTranslate['action_plan'] = actionPlan.toString();
        }

        if (studyResources != null &&
            studyResources.toString().trim().isNotEmpty) {
          textsToTranslate['study_resources'] = studyResources.toString();
        }

        // Translate all fields in one batch request
        if (textsToTranslate.isNotEmpty) {
          try {
            final translatedMap =
                await GeminiService.translateMultipleTextsPreservingFormat(
              texts: textsToTranslate,
              targetLanguage: language,
            );

            // Update translated recommendations
            for (final entry in translatedMap.entries) {
              translatedRecommendations[entry.key] = entry.value;

              // Also update backward compatibility fields
              if (entry.key == 'performance_overview') {
                translatedRecommendations['overall_assessment'] = entry.value;
              } else if (entry.key == 'strengths') {
                translatedRecommendations['strong_areas'] = entry.value;
              } else if (entry.key == 'areas_for_improvement') {
                translatedRecommendations['weak_areas'] = entry.value;
              } else if (entry.key == 'learning_strategies') {
                translatedRecommendations['learning_recommendations'] =
                    entry.value;
              } else if (entry.key == 'action_plan') {
                translatedRecommendations['next_steps'] = entry.value;
              }
            }

            debugPrint(
                'Batch translation completed for $language (${translatedMap.length} fields)');
          } catch (e) {
            debugPrint(
                'Error in batch translation, falling back to parallel translation: $e');
            // Fallback to parallel translation if batch fails
            final translationFutures = <String, Future<String>>{};
            for (final entry in textsToTranslate.entries) {
              translationFutures[entry.key] =
                  GeminiService.translateTextPreservingFormat(
                text: entry.value,
                targetLanguage: language,
              );
            }

            final translationResults = await Future.wait(
              translationFutures.entries.map((entry) async {
                try {
                  final translated = await entry.value;
                  return MapEntry(entry.key, translated);
                } catch (e) {
                  debugPrint('Error translating ${entry.key}: $e');
                  return MapEntry(entry.key, textsToTranslate[entry.key] ?? '');
                }
              }),
            );

            for (final entry in translationResults) {
              translatedRecommendations[entry.key] = entry.value;
              if (entry.key == 'performance_overview') {
                translatedRecommendations['overall_assessment'] = entry.value;
              } else if (entry.key == 'strengths') {
                translatedRecommendations['strong_areas'] = entry.value;
              } else if (entry.key == 'areas_for_improvement') {
                translatedRecommendations['weak_areas'] = entry.value;
              } else if (entry.key == 'learning_strategies') {
                translatedRecommendations['learning_recommendations'] =
                    entry.value;
              } else if (entry.key == 'action_plan') {
                translatedRecommendations['next_steps'] = entry.value;
              }
            }
          }
        }
      }

      // Save the recommendations to the database
      final recommendationData = {
        'quiz_attempt_id': quizAttemptId,
        'performance_overview':
            translatedRecommendations['overall_assessment'] ??
                translatedRecommendations['performance_overview'],
        'strengths': translatedRecommendations['strong_areas'] ??
            translatedRecommendations['strengths'],
        'areas_for_improvement': translatedRecommendations['weak_areas'] ??
            translatedRecommendations['areas_for_improvement'],
        'learning_strategies':
            translatedRecommendations['learning_recommendations'] ??
                translatedRecommendations['learning_strategies'],
        'action_plan': translatedRecommendations['next_steps'] ??
            translatedRecommendations['action_plan'],
        // Keep the old field names too for backward compatibility
        'overall_assessment': translatedRecommendations['overall_assessment'] ??
            translatedRecommendations['performance_overview'],
        'weak_areas': translatedRecommendations['weak_areas'] ??
            translatedRecommendations['areas_for_improvement'],
        'strong_areas': translatedRecommendations['strong_areas'] ??
            translatedRecommendations['strengths'],
        'learning_recommendations':
            translatedRecommendations['learning_recommendations'] ??
                translatedRecommendations['learning_strategies'],
        'next_steps': translatedRecommendations['next_steps'] ??
            translatedRecommendations['action_plan'],
      };

      final response = await SupabaseService.client
          .from('ai_recommendations')
          .insert(recommendationData)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error generating quiz recommendation: $e');
      return null;
    }
  }

  /// Delete a recommendation by quiz attempt ID
  static Future<void> deleteRecommendation(String quizAttemptId) async {
    try {
      await SupabaseService.client
          .from('ai_recommendations')
          .delete()
          .eq('quiz_attempt_id', quizAttemptId);
    } catch (e) {
      debugPrint('Error deleting recommendation: $e');
      rethrow;
    }
  }
}
