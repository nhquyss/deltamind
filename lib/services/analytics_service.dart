import 'package:deltamind/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Model class for quiz analytics
class QuizAnalytics {
  final String userId;
  final String? categoryId;
  final String? categoryName;
  final int totalAttempts;
  final int totalCorrectAnswers;
  final int totalQuestionsAttempted;
  final double averageScore;
  final int? averageTimePerQuestion;
  final String? strongestCategoryId;
  final String? strongestCategoryName;
  final String? weakestCategoryId;
  final String? weakestCategoryName;
  final DateTime? lastUpdated;

  QuizAnalytics({
    required this.userId,
    this.categoryId,
    this.categoryName,
    required this.totalAttempts,
    required this.totalCorrectAnswers,
    required this.totalQuestionsAttempted,
    required this.averageScore,
    this.averageTimePerQuestion,
    this.strongestCategoryId,
    this.strongestCategoryName,
    this.weakestCategoryId,
    this.weakestCategoryName,
    this.lastUpdated,
  });

  factory QuizAnalytics.fromJson(
    Map<String, dynamic> json, {
    Map<String, String>? categoryNames,
  }) {
    String? strongestCatName;
    String? weakestCatName;
    String? catName;

    if (categoryNames != null) {
      if (json['strongest_category'] != null) {
        strongestCatName = categoryNames[json['strongest_category']];
      }
      if (json['weakest_category'] != null) {
        weakestCatName = categoryNames[json['weakest_category']];
      }
      if (json['category_id'] != null) {
        catName = categoryNames[json['category_id']];
      }
    }

    return QuizAnalytics(
      userId: json['user_id'],
      categoryId: json['category_id'],
      categoryName: catName ?? json['category_name'],
      totalAttempts: json['total_attempts'] ?? 0,
      totalCorrectAnswers: json['total_correct_answers'] ?? 0,
      totalQuestionsAttempted: json['total_questions_attempted'] ?? 0,
      averageScore: (json['average_score'] ?? 0).toDouble(),
      averageTimePerQuestion: json['average_time_per_question'],
      strongestCategoryId: json['strongest_category'],
      strongestCategoryName: strongestCatName,
      weakestCategoryId: json['weakest_category'],
      weakestCategoryName: weakestCatName,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : null,
    );
  }
}

/// Model class for study time analytics
class StudyTimeAnalytics {
  final String userId;
  final int totalStudyTimeMinutes;
  final Map<String, int> studyTimeByDay;
  final Map<String, int> studyTimeByCategory;
  final DateTime? lastUpdated;

  StudyTimeAnalytics({
    required this.userId,
    required this.totalStudyTimeMinutes,
    required this.studyTimeByDay,
    required this.studyTimeByCategory,
    this.lastUpdated,
  });

  factory StudyTimeAnalytics.fromJson(
    Map<String, dynamic> json, {
    Map<String, String>? categoryNames,
  }) {
    Map<String, int> timeByDay = {};
    if (json['study_time_by_day'] != null) {
      (json['study_time_by_day'] as Map<String, dynamic>).forEach((key, value) {
        timeByDay[key] = value as int;
      });
    }

    Map<String, int> timeByCategory = {};
    if (json['study_time_by_category'] != null) {
      (json['study_time_by_category'] as Map<String, dynamic>).forEach((
        key,
        value,
      ) {
        final categoryName = categoryNames?[key] ?? key;
        timeByCategory[categoryName] = value as int;
      });
    }

    return StudyTimeAnalytics(
      userId: json['user_id'],
      totalStudyTimeMinutes: json['total_study_time_minutes'] ?? 0,
      studyTimeByDay: timeByDay,
      studyTimeByCategory: timeByCategory,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : null,
    );
  }
}

/// Service for fetching analytics data
class AnalyticsService {
  /// Get overall quiz analytics for the current user
  static Future<QuizAnalytics> getOverallQuizAnalytics() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get all category names for reference
      final categoryMap = await _getCategoryMap();

      // Mendapatkan data dari SQL untuk mendapatkan hasil yang paling akurat
      final dynamic rpcRawResponse = await SupabaseService.client.rpc(
        'get_user_overall_analytics',
        params: {'p_user_id_param': userId},
      );

      final Map<String, dynamic>? overallAnalyticsData =
          _extractMapData(rpcRawResponse);

      if (overallAnalyticsData != null) {
        // Extract values with proper null handling to ensure accuracy
        final averageScore =
            overallAnalyticsData['average_score']?.toDouble() ?? 0.0;
        final totalAttempts = overallAnalyticsData['total_attempts'] ?? 0;
        final totalCorrect = overallAnalyticsData['total_correct_answers'] ?? 0;
        final totalQuestions =
            overallAnalyticsData['total_questions_attempted'] ?? 0;

        // Get strongest and weakest categories if they exist
        final strongestCategoryId = overallAnalyticsData['strongest_category'];
        final weakestCategoryId = overallAnalyticsData['weakest_category'];

        // Format the lastUpdated datetime
        final lastUpdated = overallAnalyticsData['last_updated'] != null
            ? DateTime.parse(overallAnalyticsData['last_updated'])
            : DateTime.now();

        return QuizAnalytics(
          userId: userId,
          totalAttempts: totalAttempts,
          totalCorrectAnswers: totalCorrect,
          totalQuestionsAttempted: totalQuestions,
          averageScore: averageScore,
          strongestCategoryId: strongestCategoryId,
          strongestCategoryName: categoryMap[strongestCategoryId],
          weakestCategoryId: weakestCategoryId,
          weakestCategoryName: categoryMap[weakestCategoryId],
          lastUpdated: lastUpdated,
        );
      }
      debugPrint(
          'RPC get_user_overall_analytics failed or returned unexpected data, falling back to direct table access.');

      // Get data directly from tables if RPC fails
      final attemptsResponse = await SupabaseService.client
          .from('quiz_attempts')
          .select('score, total_questions')
          .eq('user_id', userId);

      if (attemptsResponse != null && attemptsResponse.isNotEmpty) {
        int totalAttempts = attemptsResponse.length;
        int totalCorrect = 0;
        int totalQuestions = 0;

        for (final attempt in attemptsResponse) {
          totalCorrect += (attempt['score'] as num?)?.toInt() ?? 0;
          totalQuestions += (attempt['total_questions'] as num?)?.toInt() ?? 0;
        }

        final averageScore =
            totalQuestions > 0 ? (totalCorrect * 100.0 / totalQuestions) : 0.0;

        return QuizAnalytics(
          userId: userId,
          totalAttempts: totalAttempts,
          totalCorrectAnswers: totalCorrect,
          totalQuestionsAttempted: totalQuestions,
          averageScore: averageScore,
          lastUpdated: DateTime.now(),
        );
      }

      // Return a QuizAnalytics object with zeros if no data exists
      // This is better than showing fake data
      return QuizAnalytics(
        userId: userId,
        totalAttempts: 0,
        totalCorrectAnswers: 0,
        totalQuestionsAttempted: 0,
        averageScore: 0.0,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting overall quiz analytics: $e');
      // Return object with zeros instead of fake data
      return QuizAnalytics(
        userId: SupabaseService.currentUser?.id ?? 'unknown',
        totalAttempts: 0,
        totalCorrectAnswers: 0,
        totalQuestionsAttempted: 0,
        averageScore: 0.0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Get quiz analytics by category for the current user
  static Future<List<QuizAnalytics>> getQuizAnalyticsByCategory() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get all category names for reference
      final categoryMap = await _getCategoryMap();

      // Get all analytics for this user
      final response = await SupabaseService.client
          .from('quiz_analytics')
          .select()
          .eq('user_id', userId);

      if (response == null || response.isEmpty) {
        return [];
      }

      // Filter out entries where category_id is null
      final categoryAnalytics = (response as List)
          .where((record) => record['category_id'] != null)
          .map(
            (item) => QuizAnalytics.fromJson(item, categoryNames: categoryMap),
          )
          .toList();

      return categoryAnalytics;
    } catch (e) {
      debugPrint('Error getting quiz analytics by category: $e');
      return [];
    }
  }

  /// Get performance by category for the current user (most recent attempts)
  static Future<List<Map<String, dynamic>>>
      getRecentPerformanceByCategory() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get user performance by category from the view
      final response = await SupabaseService.client
          .from('user_performance_by_category')
          .select()
          .eq('user_id', userId)
          .order('quiz_attempt_id', ascending: false);

      if (response == null || response.isEmpty) {
        return [];
      }

      return response;
    } catch (e) {
      debugPrint('Error getting recent performance by category: $e');
      return [];
    }
  }

  /// Get streak data for analytics
  static Future<Map<String, dynamic>> getStreakAnalytics() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Panggil fungsi RPC untuk mendapatkan data yang akurat
      final dynamic rpcRawResponse = await SupabaseService.client.rpc(
        'get_user_streak_data',
        params: {'p_user_id_param': userId},
      );

      final Map<String, dynamic>? rpcData = _extractMapData(rpcRawResponse);

      if (rpcData != null) {
        return {
          'current_streak': _parseInt(rpcData['current_streak']) ?? 0,
          'longest_streak': _parseInt(rpcData['longest_streak']) ?? 0,
          'last_activity_date': rpcData['last_activity_date'],
          'is_streak_freeze_active':
              rpcData['is_streak_freeze_active'] ?? false,
          'streak_freezes_available':
              _parseInt(rpcData['streak_freezes_available']) ?? 0,
          'streak_freezes_used': _parseInt(rpcData['streak_freezes_used']) ?? 0,
        };
      }

      // Fallback ke cara lama jika RPC tidak berhasil
      debugPrint(
          'RPC failed or returned unexpected data, falling back to direct table access for streak analytics.');
      final dynamic rawStreakTableResponse = await SupabaseService.client
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .single();
      final Map<String, dynamic>? streakTableData =
          _extractMapData(rawStreakTableResponse);

      final dynamic rawFreezeTableResponse = await SupabaseService.client
          .from('streak_freezes')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      final Map<String, dynamic>? freezeTableData =
          _extractMapData(rawFreezeTableResponse);

      if (streakTableData != null) {
        // Database uses 'available_count', not 'available_freezes'
        final availableFreezes =
            _parseInt(freezeTableData?['available_count']) ??
                _parseInt(freezeTableData?['available_freezes']) ??
                0;
        return {
          'current_streak': _parseInt(streakTableData['current_streak']) ?? 0,
          'longest_streak': _parseInt(streakTableData['longest_streak']) ?? 0,
          'last_activity_date': streakTableData['last_activity_date'],
          'is_streak_freeze_active':
              streakTableData['is_streak_freeze_active'] ?? false,
          'streak_freezes_available': availableFreezes,
          'streak_freezes_used':
              _parseInt(streakTableData['streak_freezes_used']) ?? 0,
        };
      }

      debugPrint(
          'No streak data found through RPC or direct table access after fallback.');
      // If all attempts fail, return default values consistent with catch block
      return {
        'current_streak': 0,
        'longest_streak': 0,
        'last_activity_date': null,
        'is_streak_freeze_active': false,
        'streak_freezes_available': 0,
        'streak_freezes_used': 0,
      };
    } catch (e) {
      debugPrint('Error getting streak analytics: $e');

      // Kalau error, berikan data default yang bagus
      return {
        'current_streak': 0,
        'longest_streak': 0,
        'last_activity_date': null,
        'is_streak_freeze_active': false,
        'streak_freezes_available': 0,
        'streak_freezes_used': 0,
      };
    }
  }

  /// Get daily activity analytics (quiz counts by day for last 30 days)
  static Future<Map<String, int>> getDailyActivityAnalytics() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get the date 30 days ago
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      // Get quiz attempts for the last 30 days with completed=true
      final response = await SupabaseService.client
          .from('quiz_attempts')
          .select('created_at')
          .eq('user_id', userId)
          .eq('completed', true)
          .gte('created_at', thirtyDaysAgo.toIso8601String());

      // Process quiz attempts
      Map<String, int> activityByDay = {};

      if (response != null && response.isNotEmpty) {
        for (final item in response) {
          final date = DateTime.parse(item['created_at']);
          final dayKey = _formatDateKey(date);

          if (activityByDay.containsKey(dayKey)) {
            activityByDay[dayKey] = activityByDay[dayKey]! + 1;
          } else {
            activityByDay[dayKey] = 1;
          }
        }

        debugPrint(
          'Activity data loaded: ${activityByDay.length} days with activity',
        );
      } else {
        debugPrint('No quiz attempts found for this user');
      }

      return activityByDay;
    } catch (e) {
      debugPrint('Error getting daily activity analytics: $e');
      return {}; // Return empty map on error
    }
  }

  // Helper method to format date as key
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper method to safely parse an integer
  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    debugPrint(
        'AnalyticsService._parseInt: Unexpected type for value: ${value.runtimeType}');
    return null;
  }

  // Helper method to safely extract Map<String, dynamic> from various data types
  static Map<String, dynamic>? _extractMapData(dynamic rawData) {
    if (rawData == null) {
      return null;
    }
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is List) {
      if (rawData.isNotEmpty && rawData.first is Map<String, dynamic>) {
        return rawData.first as Map<String, dynamic>;
      }
      debugPrint(
          'AnalyticsService._extractMapData: Input List was empty or first item not a Map: $rawData');
      return null;
    }
    if (rawData is String) {
      try {
        final decodedJson = jsonDecode(rawData);
        if (decodedJson is Map<String, dynamic>) {
          return decodedJson;
        } else if (decodedJson is List) {
          if (decodedJson.isNotEmpty &&
              decodedJson.first is Map<String, dynamic>) {
            return decodedJson.first as Map<String, dynamic>;
          }
          debugPrint(
              'AnalyticsService._extractMapData: Decoded JSON List was empty or first item not a Map: $decodedJson');
        } else {
          debugPrint(
              'AnalyticsService._extractMapData: Decoded JSON was not a Map or List: ${decodedJson.runtimeType}');
        }
      } catch (e) {
        debugPrint(
            'AnalyticsService._extractMapData: Failed to jsonDecode String: $e, Data: $rawData');
      }
      return null;
    }
    debugPrint(
        'AnalyticsService._extractMapData: Could not extract map from data of type ${rawData.runtimeType}');
    return null;
  }

  /// Get category map (id -> name)
  static Future<Map<String, String>> _getCategoryMap() async {
    try {
      final response =
          await SupabaseService.client.from('categories').select('id, name');

      if (response == null || response.isEmpty) {
        // Fallback to quiz_categories if the new table is empty
        try {
          final fallbackResponse = await SupabaseService.client
              .from('quiz_categories')
              .select('id, name');

          if (fallbackResponse == null || fallbackResponse.isEmpty) {
            return {};
          }

          Map<String, String> categoryMap = {};
          for (final category in fallbackResponse) {
            categoryMap[category['id']] = category['name'];
          }

          return categoryMap;
        } catch (e) {
          debugPrint('Error getting category map from fallback: $e');
          return {};
        }
      }

      Map<String, String> categoryMap = {};
      for (final category in response) {
        categoryMap[category['id']] = category['name'];
      }

      return categoryMap;
    } catch (e) {
      debugPrint('Error getting category map: $e');
      // Return empty map instead of throwing to prevent cascading errors
      return {};
    }
  }

  /// Get quiz accuracy data for the chart
  static Future<List<Map<String, dynamic>>> getQuizAccuracyData() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get quiz attempts for the last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final formattedDate = sevenDaysAgo.toIso8601String();

      try {
        final response = await SupabaseService.client
            .from('quiz_attempts')
            .select('created_at, score, total_questions')
            .eq('user_id', userId)
            .eq('completed', true)
            .gte('created_at', formattedDate)
            .order('created_at');

        if (response != null && response.isNotEmpty) {
          // Group attempts by day and calculate average accuracy
          final Map<String, List<Map<String, dynamic>>> attemptsByDay = {};

          for (final attempt in response) {
            final createdAt = DateTime.parse(attempt['created_at']);
            final dayKey = _formatDateKey(createdAt);

            if (!attemptsByDay.containsKey(dayKey)) {
              attemptsByDay[dayKey] = [];
            }

            attemptsByDay[dayKey]!.add(attempt);
          }

          // Calculate daily accuracy percentages
          final List<Map<String, dynamic>> accuracyData = [];

          attemptsByDay.forEach((day, attempts) {
            int totalCorrect = 0;
            int totalQuestions = 0;

            for (final attempt in attempts) {
              totalCorrect += (attempt['score'] as num?)?.toInt() ?? 0;
              totalQuestions +=
                  (attempt['total_questions'] as num?)?.toInt() ?? 0;
            }

            final accuracy = totalQuestions > 0
                ? (totalCorrect * 100.0 / totalQuestions)
                : 0.0;

            // Use the day key for date
            final dateStr = '${day}T00:00:00Z';
            accuracyData.add({
              'attempt_date': dateStr,
              'accuracy_percentage': accuracy,
            });
          });

          // Sort by date
          accuracyData.sort(
            (a, b) => DateTime.parse(
              a['attempt_date'],
            ).compareTo(DateTime.parse(b['attempt_date'])),
          );

          if (accuracyData.isNotEmpty) {
            return accuracyData;
          }
        }
      } catch (queryError) {
        debugPrint('Error querying quiz attempts: $queryError');
        // Continue to fallback data
      }

      // Default fallback data
      return []; // Return an empty list instead of mock data
    } catch (e) {
      debugPrint('Error getting quiz accuracy data: $e');
      // Return sample data on error
      return []; // Return an empty list instead of mock data
    }
  }

  // Helper method to get default accuracy data
  static List<Map<String, dynamic>> _getDefaultAccuracyData() {
    final now = DateTime.now();
    return [
      {
        'attempt_date': now.subtract(const Duration(days: 3)).toIso8601String(),
        'accuracy_percentage': 48.0,
      },
      {
        'attempt_date': now.subtract(const Duration(days: 2)).toIso8601String(),
        'accuracy_percentage': 70.6,
      },
      {
        'attempt_date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'accuracy_percentage': 75.0,
      },
      {'attempt_date': now.toIso8601String(), 'accuracy_percentage': 51.85},
    ];
  }

  /// Get total quizzes created by the user
  static Future<int> getTotalQuizzesCreated() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get count of quizzes created by the user
      final response = await SupabaseService.client
          .from('quizzes')
          .select()
          .eq('user_id', userId);

      if (response != null) {
        return (response as List).length;
      }

      return 0;
    } catch (e) {
      debugPrint('Error getting total quizzes created: $e');
      return 0;
    }
  }

  /// Get total quizzes completed by the user
  static Future<int> getTotalQuizzesCompleted() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get count of completed quiz attempts by the user
      final response = await SupabaseService.client
          .from('quiz_attempts')
          .select()
          .eq('user_id', userId)
          .eq('completed', true);

      if (response != null) {
        return (response as List).length;
      }

      return 0;
    } catch (e) {
      debugPrint('Error getting total quizzes completed: $e');
      return 0;
    }
  }
}
