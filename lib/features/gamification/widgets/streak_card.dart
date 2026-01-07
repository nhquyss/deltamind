import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/features/gamification/widgets/streak_freeze_widget.dart';
import 'package:deltamind/services/streak_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:deltamind/features/gamification/widgets/streak_freeze_countdown.dart';

class StreakCard extends StatefulWidget {
  final UserStreak streak;
  final StreakFreeze? streakFreeze;
  final bool isDetailed;
  final VoidCallback? onTap;

  const StreakCard({
    super.key,
    required this.streak,
    this.streakFreeze,
    this.isDetailed = false,
    this.onTap,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  Set<String>? _activityDates;

  @override
  void initState() {
    super.initState();
    _loadActivityDates();
  }

  @override
  void didUpdateWidget(StreakCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload activity dates if streak changed
    if (oldWidget.streak.currentStreak != widget.streak.currentStreak ||
        oldWidget.streak.activityDateStr != widget.streak.activityDateStr) {
      _loadActivityDates();
    }
  }

  Future<void> _loadActivityDates() async {
    try {
      final activityDates = await StreakService.getActivityDatesLast7Days();
      if (mounted) {
        setState(() {
          _activityDates = activityDates;
        });
      }
    } catch (e) {
      debugPrint('Error loading activity dates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStreakFreezes = widget.streakFreeze != null &&
        widget.streakFreeze!.availableFreezes > 0;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.accent.withOpacity(0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: widget.onTap,
        splashColor: AppColors.accent.withOpacity(0.1),
        highlightColor: AppColors.accent.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  if (widget.streak.isStreakFreezeActive) ...[
                    const SizedBox(height: 16),
                    _buildActiveStreakFreezeIndicator(
                      context,
                      widget.streak.streakFreezeExpiry,
                    ),
                  ],
                  if (hasStreakFreezes) ...[
                    const SizedBox(height: 12),
                    StreakFreezeWidget(compact: false),
                  ],
                  const SizedBox(height: 20),
                  _buildStreakStats(context),
                  if (widget.isDetailed)
                    _buildDetailedContent(context, constraints),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    // final streak = widget.streak;
    // final isStreakAchievedToday = streak.isStreakAchievedToday;

    // // Use orange gradient if streak achieved today, otherwise use accent color
    // final iconColor =
    //     isStreakAchievedToday ? Colors.orange.shade600 : AppColors.accent;
    // final iconGradientColors = isStreakAchievedToday
    //     ? [Colors.orange.shade600, Colors.orange.shade400]
    //     : [AppColors.accent, AppColors.accent.withOpacity(0.8)];

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)],
              // colors: iconGradientColors,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.3),
                // color: iconColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            PhosphorIconsFill.flame,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Streak',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Keep practicing daily!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakStats(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: _buildStreakStat(
            context,
            'Current',
            widget.streak.currentStreak.toString(),
            PhosphorIconsFill.flame,
            AppColors.accent,
          ),
        ),
        Container(
          height: 40,
          width: 1,
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        Expanded(
          child: _buildStreakStat(
            context,
            'Longest',
            widget.streak.longestStreak.toString(),
            PhosphorIconsFill.trophy,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedContent(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        // Last active date
        Row(
          children: [
            Icon(
              PhosphorIconsFill.calendar,
              size: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'Last Active: ',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Text(
                widget.streak.activityDateStr != null &&
                        widget.streak.activityDateStr!.isNotEmpty
                    ? DateFormat.yMMMd()
                        .format(DateTime.parse(widget.streak.activityDateStr!))
                    : DateFormat.yMMMd().format(widget.streak.lastActivityDate),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Weekly activity graph
        _buildAccurateWeeklyActivity(context, constraints),
      ],
    );
  }

  Widget _buildAccurateWeeklyActivity(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final theme = Theme.of(context);
    final availableWidth = constraints.maxWidth;
    final dayWidth =
        (availableWidth - 12) / 7; // 12 pixels for spacing between days

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 7 Days Activity',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _buildAccurateDayActivities(context, dayWidth),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAccurateDayActivities(
    BuildContext context,
    double dayWidth,
  ) {
    final now = DateTime.now();
    final dayWidgets = <Widget>[];

    // Get days from most recent to 6 days ago
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final isToday = i == 0;
      final dayName = DateFormat('E').format(date);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dateStr = dateOnly.toIso8601String().split('T')[0]; // YYYY-MM-DD

      // Check if this date has actual activity from daily_quests
      // Use _activityDates if available (from database query)
      bool isActive = false;

      if (_activityDates != null) {
        // Use actual activity dates from database - shows real activity per day
        isActive = _activityDates!.contains(dateStr);
      }
      // else {
      //   // Fallback: use old logic if activity dates not loaded yet
      //   // This will be replaced once _activityDates is loaded
      //   final streak = widget.streak;
      //   if (streak.activityDateStr != null &&
      //       streak.activityDateStr!.isNotEmpty) {
      //     try {
      //       final activityDate = DateTime.parse(streak.activityDateStr!);
      //       final activityDateOnly = DateTime(
      //         activityDate.year,
      //         activityDate.month,
      //         activityDate.day,
      //       );

      //       if (dateOnly == activityDateOnly) {
      //         isActive = true;
      //       } else if (streak.currentStreak > 0) {
      //         final lastActivityDate = activityDateOnly;
      //         final streakStartDate = lastActivityDate.subtract(
      //           Duration(days: streak.currentStreak - 1),
      //         );
      //         isActive = !dateOnly.isBefore(streakStartDate) &&
      //             !dateOnly.isAfter(lastActivityDate);
      //       }
      //     } catch (e) {
      //       debugPrint('Error parsing activity_date_str: $e');
      //     }
      //   }
      // }

      dayWidgets.add(
        SizedBox(
          width: dayWidth,
          child: _buildDayActivity(context, dayName, isActive, isToday),
        ),
      );
    }

    return dayWidgets;
  }

  Widget _buildDayActivity(
    BuildContext context,
    String dayName,
    bool isActive,
    bool isToday,
  ) {
    final theme = Theme.of(context);
    final barColor = isActive
        ? AppColors.accent
        : theme.colorScheme.onSurface.withOpacity(0.1);
    final barHeight = isActive ? 40.0 : 15.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 20, // Smaller width to avoid overflow
          height: barHeight,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 30,
          child: Text(
            dayName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isToday
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              fontSize: 10, // Smaller font size to avoid overflow
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActiveStreakFreezeIndicator(
    BuildContext context,
    DateTime? expiryTime,
  ) {
    final theme = Theme.of(context);

    // Check if already expired
    if (expiryTime != null) {
      final now = DateTime.now();
      if (expiryTime.isBefore(now)) {
        return const SizedBox.shrink();
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade100, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.5),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade200.withOpacity(0.5),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Icon(
              PhosphorIconsFill.snowflake,
              color: Colors.blue.shade700,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streak Freeze Active',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                StreakFreezeCountdown(
                  expiryTime: expiryTime,
                  textColor: Colors.blue.shade900,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
