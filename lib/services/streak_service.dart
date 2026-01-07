import 'package:deltamind/models/daily_quest.dart';
import 'package:deltamind/services/supabase_service.dart';
import 'package:flutter/foundation.dart';

/// Model class for user streak information
class UserStreak {
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final DateTime lastActivityDate;
  final DateTime? streakStartDate;
  final bool isStreakFreezeActive;
  final DateTime? streakFreezeExpiry;
  final String?
      activityDateStr; // Date string (YYYY-MM-DD) when streak was last updated

  UserStreak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityDate,
    this.streakStartDate,
    this.isStreakFreezeActive = false,
    this.streakFreezeExpiry,
    this.activityDateStr,
  });

  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      userId: json['user_id'],
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      lastActivityDate: DateTime.parse(json['last_activity_date']),
      streakStartDate: json['streak_start_date'] != null
          ? DateTime.parse(json['streak_start_date'])
          : null,
      isStreakFreezeActive: json['is_streak_freeze_active'] ?? false,
      streakFreezeExpiry: json['streak_freeze_expiry'] != null
          ? DateTime.parse(json['streak_freeze_expiry'])
          : null,
      activityDateStr: json['activity_date_str'] as String?,
    );
  }

  /// Check if streak was already achieved today
  /// Returns true if user completed a quest today and streak was updated
  bool get isStreakAchievedToday {
    if (activityDateStr == null) {
      // Fallback: check lastActivityDate if activityDateStr is not available
      // final today = DateTime.now();
      // final todayDate = DateTime(today.year, today.month, today.day);
      // final lastActivityDateOnly = DateTime(
      //   lastActivityDate.year,
      //   lastActivityDate.month,
      //   lastActivityDate.day,
      // );
      // return lastActivityDateOnly == todayDate;
      return false;
    }

    // Use activityDateStr (more reliable for timezone)
    final today = DateTime.now();
    final todayDateStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD
    return activityDateStr == todayDateStr;
  }
}

/// Model class for streak freezes
class StreakFreeze {
  final String userId;
  final int availableFreezes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StreakFreeze({
    required this.userId,
    required this.availableFreezes,
    this.createdAt,
    this.updatedAt,
  });

  factory StreakFreeze.fromJson(Map<String, dynamic> json) {
    return StreakFreeze(
      userId: json['user_id'],
      availableFreezes: json['available_freezes'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}

/// Model class for achievements
class Achievement {
  final String id;
  final String name;
  final String description;
  final String category;
  final String requirementType;
  final int requirementValue;
  final int xpReward;
  final String? iconName;
  final bool isEarned;
  final DateTime? earnedAt;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.requirementType,
    required this.requirementValue,
    required this.xpReward,
    this.iconName,
    this.isEarned = false,
    this.earnedAt,
  });

  factory Achievement.fromJson(
    Map<String, dynamic> json, {
    bool? earned,
    DateTime? earnedDate,
  }) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      requirementType: json['requirement_type'],
      requirementValue: json['requirement_value'],
      xpReward: json['xp_reward'],
      iconName: json['icon_name'],
      isEarned: earned ?? false,
      earnedAt: earnedDate,
    );
  }
}

/// Model class for user level information
class UserLevel {
  final String userId;
  final int currentLevel;
  final int currentXp;
  final int totalXpEarned;
  final int xpNeededForNextLevel;

  UserLevel({
    required this.userId,
    required this.currentLevel,
    required this.currentXp,
    required this.totalXpEarned,
    required this.xpNeededForNextLevel,
  });

  factory UserLevel.fromJson(Map<String, dynamic> json) {
    return UserLevel(
      userId: json['user_id'],
      currentLevel: json['current_level'] ?? 1,
      currentXp: json['current_xp'] ?? 0,
      totalXpEarned: json['total_xp_earned'] ?? 0,
      xpNeededForNextLevel:
          (json['current_level'] ?? 1) * 100, // Same formula as in DB
    );
  }

  /// Get progress percentage towards next level (0.0 to 1.0)
  double get levelProgress {
    return xpNeededForNextLevel > 0
        ? (currentXp / xpNeededForNextLevel).clamp(0.0, 1.0)
        : 0.0;
  }
}

/// Model class for streak freeze usage history
class StreakFreezeHistory {
  final String id;
  final String userId;
  final DateTime usedAt;
  final DateTime? expiredAt;
  final DateTime? createdAt;

  // Calculate status based on expiry
  bool get isActive => expiredAt == null || expiredAt!.isAfter(DateTime.now());

  // Calculate duration
  Duration get duration {
    if (expiredAt == null) {
      return DateTime.now().difference(usedAt);
    } else {
      return expiredAt!.difference(usedAt);
    }
  }

  // Format duration as string
  String get durationText {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    final parts = <String>[];

    if (days > 0) {
      parts.add('$days day${days > 1 ? 's' : ''}');
    }

    if (hours > 0) {
      parts.add('$hours hour${hours > 1 ? 's' : ''}');
    }

    if (minutes > 0 && days == 0) {
      // Only show minutes if less than a day
      parts.add('$minutes minute${minutes > 1 ? 's' : ''}');
    }

    if (parts.isEmpty) {
      return 'Less than a minute';
    }

    return parts.join(' ');
  }

  StreakFreezeHistory({
    required this.id,
    required this.userId,
    required this.usedAt,
    this.expiredAt,
    this.createdAt,
  });

  factory StreakFreezeHistory.fromJson(Map<String, dynamic> json) {
    return StreakFreezeHistory(
      id: json['id'],
      userId: json['user_id'],
      usedAt: DateTime.parse(json['used_at']),
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

/// Service for managing streaks and achievements
class StreakService {
  /// Get the current user's streak information
  /// Also checks and resets streak if user missed days (even if they didn't complete quests)
  static Future<UserStreak?> getUserStreak() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Getting user streak for user: $userId');

      final response = await SupabaseService.client
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .single();

      final streak = UserStreak.fromJson(response);

      // Check if streak needs to be reset (user missed days)
      // This ensures streak is reset even if user doesn't complete quests
      await _checkAndResetStreakIfNeeded(userId, streak);

      // Return updated streak
      final updatedResponse = await SupabaseService.client
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .single();

      return UserStreak.fromJson(updatedResponse);
    } catch (e) {
      debugPrint('Error getting user streak: $e');
      return null;
    }
  }

  /// Check if streak needs to be reset and reset it if user missed days
  /// This is called when loading streak data to ensure streak is always up-to-date
  static Future<void> _checkAndResetStreakIfNeeded(
      String userId, UserStreak streak) async {
    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Check using activity_date_str if available (more reliable for timezone)
      String? lastActivityDateStr;
      try {
        final streakData = await SupabaseService.client
            .from('user_streaks')
            .select('activity_date_str')
            .eq('user_id', userId)
            .single();
        lastActivityDateStr = streakData['activity_date_str'] as String?;
      } catch (e) {
        // If activity_date_str doesn't exist, use last_activity_date
        debugPrint('activity_date_str not found, using last_activity_date: $e');
      }

      // Determine last activity date
      DateTime? lastActivityDate;
      if (lastActivityDateStr != null && lastActivityDateStr.isNotEmpty) {
        // Use activity_date_str (from client, more reliable)
        lastActivityDate = DateTime.parse(lastActivityDateStr);
        lastActivityDate = DateTime(
          lastActivityDate.year,
          lastActivityDate.month,
          lastActivityDate.day,
        );
      } else {
        // Fallback to last_activity_date timestamp
        lastActivityDate = DateTime(
          streak.lastActivityDate.year,
          streak.lastActivityDate.month,
          streak.lastActivityDate.day,
        );
      }

      // Check if already updated today
      if (lastActivityDate == todayDate) {
        return; // Already updated today, no need to reset
      }

      final daysDifference = todayDate.difference(lastActivityDate).inDays;

      // If user missed more than 1 day, reset streak to 0
      // Note: We don't increment streak here (only when completing quests)
      // We only reset if streak is broken
      // Don't update activity_date_str here - it should only be updated when user completes a quest
      if (daysDifference > 1) {
        debugPrint(
          'User missed $daysDifference days, resetting streak from ${streak.currentStreak} to 0',
        );

        await SupabaseService.client.from('user_streaks').update({
          'current_streak': 0,
          // Don't update activity_date_str - keep it as the last day user actually completed a quest
          // This ensures that when user completes a quest today, recordActivity() will properly update streak
          // Don't update streak_start_date - it will be updated when user starts a new streak (streak = 1)
          'streak_start_date': null,
          'activity_date_str': null,
        }).eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('Error checking/resetting streak: $e');
      // Don't throw - streak check failure shouldn't break the app
    }
  }

  /// Get the user's level information
  static Future<UserLevel?> getUserLevel() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .from('user_levels')
          .select()
          .eq('user_id', userId)
          .single();

      return UserLevel.fromJson(response);
    } catch (e) {
      debugPrint('Error getting user level: $e');
      return null;
    }
  }

  /// Get all available achievements
  static Future<List<Achievement>> getAchievements() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get all achievements
      final achievementsResponse =
          await SupabaseService.client.from('achievements').select();

      // Get user's earned achievements
      final userAchievementsResponse = await SupabaseService.client
          .from('user_achievements')
          .select('achievement_id, earned_at')
          .eq('user_id', userId);

      // Convert to a map for easy lookup
      final Map<String, DateTime> earnedAchievements = {};
      for (final item in userAchievementsResponse) {
        earnedAchievements[item['achievement_id']] = DateTime.parse(
          item['earned_at'],
        );
      }

      // Create achievement objects with earned status
      final achievements = achievementsResponse.map<Achievement>((json) {
        final achievementId = json['id'];
        final isEarned = earnedAchievements.containsKey(achievementId);
        final earnedAt = isEarned ? earnedAchievements[achievementId] : null;

        return Achievement.fromJson(
          json,
          earned: isEarned,
          earnedDate: earnedAt,
        );
      }).toList();

      return achievements;
    } catch (e) {
      debugPrint('Error getting achievements: $e');
      return [];
    }
  }

  /// Get user's earned achievements only
  static Future<List<Achievement>> getEarnedAchievements() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .from('user_achievements')
          .select('achievements(*), earned_at')
          .eq('user_id', userId);

      return response.map<Achievement>((item) {
        final achievementJson = item['achievements'];
        final earnedAt = DateTime.parse(item['earned_at']);

        return Achievement.fromJson(
          achievementJson,
          earned: true,
          earnedDate: earnedAt,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting earned achievements: $e');
      return [];
    }
  }

  /// Get the number of available streak freezes for the current user
  static Future<StreakFreeze?> getAvailableStreakFreezes() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .from('streak_freezes')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return StreakFreeze(userId: userId, availableFreezes: 0);
      }

      return StreakFreeze.fromJson(response);
    } catch (e) {
      debugPrint('Error getting streak freezes: $e');
      return null;
    }
  }

  /// Get streak freeze usage history for the current user
  static Future<List<StreakFreezeHistory>> getStreakFreezeHistory() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .from('streak_freeze_history')
          .select()
          .eq('user_id', userId)
          .order('used_at', ascending: false)
          .limit(10);

      final history = response
          .map<StreakFreezeHistory>(
            (json) => StreakFreezeHistory.fromJson(json),
          )
          .toList();

      return history;
    } catch (e) {
      debugPrint('Error getting streak freeze history: $e');
      return [];
    }
  }

  /// Get available streak freezes for the current user
  static Future<StreakFreeze?> getUserStreakFreezes() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .from('streak_freezes')
          .select()
          .eq('user_id', userId)
          .single();

      return StreakFreeze.fromJson(response);
    } catch (e) {
      debugPrint('Error getting streak freezes: $e');
      return null;
    }
  }

  /// Use a streak freeze for the current user
  static Future<bool> useStreakFreeze() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Call the use_streak_freeze function
      final response = await SupabaseService.client
          .rpc('use_streak_freeze', params: {'p_user_id_param': userId});

      return response as bool;
    } catch (e) {
      debugPrint('Error using streak freeze: $e');
      return false;
    }
  }

  /// Get all daily quests for the current user
  static Future<List<DailyQuest>> getDailyQuests() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get today's date in YYYY-MM-DD format (client timezone)
      final now = DateTime.now();
      final todayDateStr =
          now.toIso8601String().split('T')[0]; // Format: YYYY-MM-DD

      debugPrint('Client date: $todayDateStr, calling generate_daily_quests');

      // Call generate_daily_quests RPC với date từ client để tránh timezone mismatch
      try {
        await SupabaseService.client.rpc('generate_daily_quests', params: {
          'p_user_id_param': userId,
          'p_date_param': todayDateStr, // Truyền date từ client
        });
        debugPrint(
            'Successfully called generate_daily_quests for user: $userId with date: $todayDateStr');
      } catch (e) {
        // Log but continue - the user might still have existing quests
        debugPrint('Warning: Could not generate daily quests: $e');
        // Don't return early - try to fetch existing quests anyway
      }

      // Get all active quests for the user
      // Filter theo assigned_date (hôm nay theo client timezone)
      debugPrint('Fetching daily quests for date: $todayDateStr');

      final response = await SupabaseService.client
          .from('daily_quests')
          .select()
          .eq('user_id', userId)
          .eq('assigned_date', todayDateStr) // Quest assigned today
          .order('quest_type');

      final quests = response
          .map<DailyQuest>((json) => DailyQuest.fromJson(json))
          .toList();

      debugPrint(
          'Found ${quests.length} active daily quests for user: $userId');

      // If no quests found, log a warning for debugging
      if (quests.isEmpty) {
        debugPrint(
            'Warning: No daily quests found for today. This might indicate:');
        debugPrint('  1. Quest generation failed');
        debugPrint('  2. Timezone mismatch between client and server');
        debugPrint('  3. User has no quests assigned for today');
      }

      return quests;
    } catch (e) {
      debugPrint('Error getting daily quests: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      // Return empty list instead of throwing to prevent UI crashes
      return [];
    }
  }

  /// Update progress for a specific quest type
  /// Uses client date to avoid timezone mismatch issues
  static Future<bool> updateQuestProgress(String questType,
      [int incrementBy = 1]) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get today's date in YYYY-MM-DD format (client timezone)
      // This ensures consistency with quest generation
      final now = DateTime.now();
      final todayDateStr =
          now.toIso8601String().split('T')[0]; // Format: YYYY-MM-DD

      final response =
          await SupabaseService.client.rpc('update_quest_progress', params: {
        'p_user_id_param': userId,
        'p_quest_type_param': questType,
        'p_increment_count': incrementBy,
        'p_date_param': todayDateStr, // Pass date from client
      });

      return response as bool;
    } catch (e) {
      debugPrint('Error updating quest progress: $e');
      return false;
    }
  }

  /// Reset all daily quests
  static Future<bool> resetDailyQuests() async {
    try {
      await SupabaseService.client.rpc('reset_daily_quests');
      return true;
    } catch (e) {
      debugPrint('Error resetting daily quests: $e');
      return false;
    }
  }

  /// Get actual activity dates for the last 7 days
  /// Returns a Set of date strings (YYYY-MM-DD) where user completed at least one quest
  static Future<Set<String>> getActivityDatesLast7Days() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get date range for last 7 days
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 6));
      final todayDateStr = now.toIso8601String().split('T')[0];
      final sevenDaysAgoStr = sevenDaysAgo.toIso8601String().split('T')[0];

      // Query daily_quests for completed quests in the last 7 days
      final response = await SupabaseService.client
          .from('daily_quests')
          .select('assigned_date')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .gte('assigned_date', sevenDaysAgoStr)
          .lte('assigned_date', todayDateStr);

      // Extract unique dates
      final activityDates = <String>{};
      for (final item in response) {
        final assignedDate = item['assigned_date'] as String?;
        if (assignedDate != null) {
          activityDates.add(assignedDate);
        }
      }

      return activityDates;
    } catch (e) {
      debugPrint('Error getting activity dates: $e');
      return {};
    }
  }

  /// Record user activity to update streak
  /// This should be called when user completes any quest (quiz, flashcard, note, etc.)
  /// The database function will handle:
  /// - Checking if streak was already updated today
  /// - Incrementing streak if it's a new day
  /// - Resetting streak if user missed a day
  /// - Updating longest streak if needed
  /// Uses client date to avoid timezone mismatch issues
  static Future<bool> recordActivity() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get today's date in YYYY-MM-DD format (client timezone)
      // This ensures consistency with quest generation
      final now = DateTime.now();
      final todayDateStr =
          now.toIso8601String().split('T')[0]; // Format: YYYY-MM-DD

      // Try to call RPC function first (if it exists)
      try {
        final response = await SupabaseService.client.rpc(
          'record_user_activity',
          params: {
            'p_user_id_param': userId,
            'p_date_param': todayDateStr, // Pass date from client
          },
        );
        return response as bool;
      } catch (rpcError) {
        // If RPC function doesn't exist, try direct update with logic
        debugPrint(
          'RPC function record_user_activity not found, using direct update: $rpcError',
        );
        return await _recordActivityDirect(userId);
      }
    } catch (e) {
      debugPrint('Error recording activity: $e');
      // Don't throw - streak update failure shouldn't break the app
      return false;
    }
  }

  /// Direct update method (fallback if RPC function doesn't exist)
  static Future<bool> _recordActivityDirect(String userId) async {
    try {
      // Get current streak data
      final currentStreak = await getUserStreak();
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Get today's date string (YYYY-MM-DD) for activity_date_str
      final todayDateStr = todayDate.toIso8601String().split('T')[0];

      if (currentStreak == null) {
        // Create new streak record
        await SupabaseService.client.from('user_streaks').insert({
          'user_id': userId,
          'current_streak': 1,
          'longest_streak': 1,
          'last_activity_date': todayDate.toIso8601String(),
          'activity_date_str': todayDateStr, // Store date string from client
          'streak_start_date': todayDate.toIso8601String(),
        });
        return true;
      }

      final lastActivityDate = DateTime(
        currentStreak.lastActivityDate.year,
        currentStreak.lastActivityDate.month,
        currentStreak.lastActivityDate.day,
      );

      // Check if already updated today
      if (lastActivityDate == todayDate) {
        return true; // Already updated today
      }

      final daysDifference = todayDate.difference(lastActivityDate).inDays;

      if (daysDifference == 1) {
        // Last activity was yesterday - increment streak
        final newStreak = currentStreak.currentStreak + 1;
        final newLongestStreak = newStreak > currentStreak.longestStreak
            ? newStreak
            : currentStreak.longestStreak;

        // Get today's date string (YYYY-MM-DD) for activity_date_str
        final todayDateStr = todayDate.toIso8601String().split('T')[0];

        // If streak was 0 and now becomes 1, update streak_start_date (starting new streak)
        final updateData = <String, dynamic>{
          'current_streak': newStreak,
          'longest_streak': newLongestStreak,
          'last_activity_date': todayDate.toIso8601String(),
          'activity_date_str': todayDateStr, // Store date string from client
        };

        // If starting a new streak (from 0 to 1), update streak_start_date
        if (currentStreak.currentStreak == 0) {
          updateData['streak_start_date'] = todayDate.toIso8601String();
        }

        await SupabaseService.client
            .from('user_streaks')
            .update(updateData)
            .eq('user_id', userId);
      } else if (daysDifference > 1) {
        // Last activity was more than 1 day ago - reset streak to 0
        // Note: We don't update activity_date_str here because user hasn't completed a quest today yet
        // activity_date_str will be updated when user completes their first quest today
        // Don't update streak_start_date here - it will be updated when streak becomes 1 again

        await SupabaseService.client.from('user_streaks').update({
          'current_streak': 0,
          'last_activity_date': todayDate.toIso8601String(),
          // Don't update activity_date_str - keep it as the last day user actually completed a quest
          // Don't update streak_start_date - it will be updated when user starts a new streak (streak = 1)
        }).eq('user_id', userId);
      }

      return true;
    } catch (e) {
      debugPrint('Error in direct activity recording: $e');
      return false;
    }
  }
}
