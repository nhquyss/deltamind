import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/core/utils/formatters.dart';
import 'package:deltamind/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Widget for the History tab in the QuizListPage
class QuizHistoryTab extends ConsumerStatefulWidget {
  /// Creates a QuizHistoryTab
  const QuizHistoryTab({Key? key}) : super(key: key);

  @override
  ConsumerState<QuizHistoryTab> createState() => _QuizHistoryTabState();
}

class _QuizHistoryTabState extends ConsumerState<QuizHistoryTab> {
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _quizAttempts = [];
  List<dynamic> _filteredAttempts = [];
  bool _showFilters = false;

  // Filters
  String _searchQuery = '';
  String _selectedDifficulty = 'All'; // Will be localized in build
  String _selectedQuizType = 'All'; // Will be localized in build
  String _dateFilter = 'All Time'; // Will be localized in build

  // For dropdown filters
  List<String> _difficulties = ['All'];
  List<String> _quizTypes = ['All'];
  List<String> _dateFilters = [];

  // Helper methods to map between localized and English values
  String _getEnglishDateFilter(String localizedFilter, AppLocalizations l10n) {
    if (localizedFilter == l10n.allTime) return 'All Time';
    if (localizedFilter == l10n.today) return 'Today';
    if (localizedFilter == l10n.thisWeek) return 'This Week';
    if (localizedFilter == l10n.thisMonth) return 'This Month';
    if (localizedFilter == l10n.last3Months) return 'Last 3 Months';
    return localizedFilter;
  }

  String _getLocalizedDateFilter(String englishFilter, AppLocalizations l10n) {
    switch (englishFilter) {
      case 'All Time':
        return l10n.allTime;
      case 'Today':
        return l10n.today;
      case 'This Week':
        return l10n.thisWeek;
      case 'This Month':
        return l10n.thisMonth;
      case 'Last 3 Months':
        return l10n.last3Months;
      default:
        return englishFilter;
    }
  }

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadQuizHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize date filters with localization
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      if (_dateFilters.isEmpty) {
        _dateFilters = [
          l10n.allTime,
          l10n.today,
          l10n.thisWeek,
          l10n.thisMonth,
          l10n.last3Months,
        ];
      }
      // Update current filter to localized version if it's still in English
      if (_dateFilter == 'All Time' ||
          _dateFilter == 'Today' ||
          _dateFilter == 'This Week' ||
          _dateFilter == 'This Month' ||
          _dateFilter == 'Last 3 Months') {
        _dateFilter = _getLocalizedDateFilter(_dateFilter, l10n);
      }
      // Update difficulty and quiz type to localized versions if they're still in English
      if (_selectedDifficulty == 'All' ||
          _selectedDifficulty == 'easy' ||
          _selectedDifficulty == 'medium' ||
          _selectedDifficulty == 'hard' ||
          _selectedDifficulty == 'expert') {
        _selectedDifficulty =
            _getLocalizedDifficulty(_selectedDifficulty, l10n);
      }
      if (_selectedQuizType == 'All' ||
          _selectedQuizType == 'Multiple Choice' ||
          _selectedQuizType == 'True/False' ||
          _selectedQuizType == 'Fill in the Blank') {
        _selectedQuizType = _getLocalizedQuizType(_selectedQuizType, l10n);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load quiz history data
  Future<void> _loadQuizHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get quiz attempts with quiz details
      final response =
          await SupabaseService.client.from('quiz_attempts').select('''
            id, 
            score, 
            total_questions, 
            time_taken, 
            created_at,
            user_id,
            quizzes (
              id, 
              title, 
              quiz_type,
              difficulty
            )
          ''').eq('user_id', userId).order('created_at', ascending: false);

      if (mounted) {
        // Process the data for filters
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          final difficulties = <String>{l10n.quizDifficultyAll};
          final quizTypes = <String>{l10n.quizTypeAll};

          for (final attempt in response) {
            final quiz = attempt['quizzes'];
            if (quiz != null) {
              if (quiz['difficulty'] != null) {
                final difficultyValue = quiz['difficulty'].toString();
                // Normalize and localize difficulty
                final localizedDifficulty = _getLocalizedDifficulty(
                  difficultyValue,
                  l10n,
                );
                // Only add if it's a valid localized value (not the original English)
                if (localizedDifficulty != difficultyValue ||
                    localizedDifficulty == l10n.quizDifficultyAll ||
                    localizedDifficulty == l10n.quizDifficultyEasy ||
                    localizedDifficulty == l10n.quizDifficultyMedium ||
                    localizedDifficulty == l10n.quizDifficultyHard ||
                    localizedDifficulty == l10n.quizDifficultyExpert) {
                  difficulties.add(localizedDifficulty);
                }
              }
              if (quiz['quiz_type'] != null) {
                final quizTypeValue = quiz['quiz_type'].toString();
                // Normalize and localize quiz type
                final localizedQuizType = _getLocalizedQuizType(
                  quizTypeValue,
                  l10n,
                );
                // Only add if it's a valid localized value (not the original English)
                if (localizedQuizType != quizTypeValue ||
                    localizedQuizType == l10n.quizTypeAll ||
                    localizedQuizType == l10n.quizTypeMultipleChoice ||
                    localizedQuizType == l10n.quizTypeTrueFalse ||
                    localizedQuizType == l10n.quizTypeFillInTheBlank) {
                  quizTypes.add(localizedQuizType);
                }
              }
            }
          }

          setState(() {
            _quizAttempts = response;
            _filteredAttempts = List.from(response);
            _isLoading = false;
            // Sort with "All" always first, then alphabetically
            _difficulties = difficulties.toList()
              ..sort((a, b) {
                if (a == l10n.quizDifficultyAll) return -1;
                if (b == l10n.quizDifficultyAll) return 1;
                return a.compareTo(b);
              });
            _quizTypes = quizTypes.toList()
              ..sort((a, b) {
                if (a == l10n.quizTypeAll) return -1;
                if (b == l10n.quizTypeAll) return 1;
                return a.compareTo(b);
              });
          });
        } else {
          setState(() {
            _quizAttempts = response;
            _filteredAttempts = List.from(response);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n?.errorLoadingQuizHistoryMessage(e.toString()) ??
              'Error loading quiz history: $e';
          _isLoading = false;
        });
        debugPrint('Error loading quiz history: $e');
      }
    }
  }

  /// Delete a quiz attempt
  Future<void> _deleteQuizAttempt(dynamic attempt) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteQuizAttempt),
        content: Text(l10n.deleteQuizAttemptConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    try {
      // Mark as deleting for UI update
      setState(() {
        attempt['_isDeleting'] = true;
      });

      // Delete the quiz attempt
      await SupabaseService.deleteQuizAttempt(attempt['id']);

      // Reload quiz history if successful
      await _loadQuizHistory();
    } catch (e) {
      // If there's an error, unmark as deleting and show error
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          attempt['_isDeleting'] = false;
          _errorMessage = l10n?.errorDeletingQuizAttempt(e.toString()) ??
              'Error deleting quiz attempt: $e';
        });
      }
      debugPrint('Error deleting quiz attempt: $e');
    }
  }

  /// Apply all filters to the data
  void _applyFilters() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final List<dynamic> filtered = [];

    for (final attempt in _quizAttempts) {
      final quiz = attempt['quizzes'];
      final quizTitle = quiz?['title'] ?? l10n.untitledQuiz;
      final difficulty = quiz?['difficulty'] ?? 'Unknown';
      final quizType = quiz?['quiz_type'] ?? 'Unknown';
      final createdAt = DateTime.parse(attempt['created_at']);

      // Apply search filter
      if (_searchQuery.isNotEmpty &&
          !quizTitle.toLowerCase().contains(_searchQuery.toLowerCase())) {
        continue;
      }

      // Apply difficulty filter
      final englishDifficulty =
          _getEnglishDifficulty(_selectedDifficulty, l10n);
      if (englishDifficulty != 'All') {
        // Normalize both values for comparison
        final normalizedDbDifficulty = difficulty.toLowerCase().trim();
        final normalizedSelectedDifficulty =
            englishDifficulty.toLowerCase().trim();

        // Handle various formats
        bool matches = false;
        if (normalizedDbDifficulty == normalizedSelectedDifficulty) {
          matches = true;
        } else if (normalizedSelectedDifficulty == 'expert' &&
            (normalizedDbDifficulty == 'advanced' ||
                normalizedDbDifficulty == 'expert')) {
          matches = true;
        } else if (normalizedSelectedDifficulty == 'medium' &&
            (normalizedDbDifficulty == 'intermediate' ||
                normalizedDbDifficulty == 'medium')) {
          matches = true;
        } else if (normalizedSelectedDifficulty == 'easy' &&
            (normalizedDbDifficulty == 'beginner' ||
                normalizedDbDifficulty == 'easy')) {
          matches = true;
        }

        if (!matches) continue;
      }

      // Apply quiz type filter
      final englishQuizType = _getEnglishQuizType(_selectedQuizType, l10n);
      if (englishQuizType != 'All') {
        // Normalize both values for comparison
        final normalizedDbQuizType = quizType.toLowerCase().trim();
        final normalizedSelectedQuizType = englishQuizType.toLowerCase().trim();

        // Handle various formats
        bool matches = false;
        if (normalizedDbQuizType == normalizedSelectedQuizType) {
          matches = true;
        } else if (normalizedSelectedQuizType == 'multiple choice') {
          matches = normalizedDbQuizType == 'multiple choice' ||
              normalizedDbQuizType == 'multiple_choice' ||
              normalizedDbQuizType == 'multiplechoice';
        } else if (normalizedSelectedQuizType == 'true/false') {
          matches = normalizedDbQuizType == 'true/false' ||
              normalizedDbQuizType == 'true_false' ||
              normalizedDbQuizType == 'true false';
        } else if (normalizedSelectedQuizType == 'fill in the blank') {
          matches = normalizedDbQuizType == 'fill in the blank' ||
              normalizedDbQuizType == 'fill_in_the_blank' ||
              normalizedDbQuizType == 'fillintheblank';
        }

        if (!matches) continue;
      }

      // Apply date filter
      final englishDateFilter = _getEnglishDateFilter(_dateFilter, l10n);
      if (englishDateFilter != 'All Time') {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final createdDate = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
        );

        switch (englishDateFilter) {
          case 'Today':
            if (createdDate != today) continue;
            break;
          case 'This Week':
            final startOfWeek = today.subtract(
              Duration(days: today.weekday - 1),
            );
            if (createdDate.isBefore(startOfWeek)) continue;
            break;
          case 'This Month':
            final startOfMonth = DateTime(now.year, now.month, 1);
            if (createdDate.isBefore(startOfMonth)) continue;
            break;
          case 'Last 3 Months':
            final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
            if (createdDate.isBefore(threeMonthsAgo)) continue;
            break;
        }
      }

      filtered.add(attempt);
    }

    setState(() {
      _filteredAttempts = filtered;
    });
  }

  // Helper methods to map between localized and English values
  String _getEnglishQuizType(String localizedType, AppLocalizations l10n) {
    if (localizedType == l10n.quizTypeAll) return 'All';
    if (localizedType == l10n.quizTypeMultipleChoice) return 'Multiple Choice';
    if (localizedType == l10n.quizTypeTrueFalse) return 'True/False';
    if (localizedType == l10n.quizTypeFillInTheBlank)
      return 'Fill in the Blank';
    return localizedType;
  }

  String _getEnglishDifficulty(
      String localizedDifficulty, AppLocalizations l10n) {
    if (localizedDifficulty == l10n.quizDifficultyAll) return 'All';
    if (localizedDifficulty == l10n.quizDifficultyEasy) return 'easy';
    if (localizedDifficulty == l10n.quizDifficultyMedium) return 'medium';
    if (localizedDifficulty == l10n.quizDifficultyHard) return 'hard';
    if (localizedDifficulty == l10n.quizDifficultyExpert) return 'expert';
    return localizedDifficulty;
  }

  String _getLocalizedDifficulty(
      String englishDifficulty, AppLocalizations l10n) {
    // Normalize the input to handle different formats from database
    final normalized = englishDifficulty.toLowerCase().trim();

    switch (normalized) {
      case 'all':
        return l10n.quizDifficultyAll;
      case 'easy':
      case 'beginner': // Some databases might use "beginner" instead of "easy"
        return l10n.quizDifficultyEasy;
      case 'medium':
      case 'intermediate': // Some databases might use "intermediate" instead of "medium"
        return l10n.quizDifficultyMedium;
      case 'hard':
      case 'difficult':
        return l10n.quizDifficultyHard;
      case 'expert':
      case 'advanced': // Handle "advanced" as "expert" difficulty
        return l10n.quizDifficultyExpert;
      default:
        // If it's already a localized value, return as is
        if (englishDifficulty == l10n.quizDifficultyAll ||
            englishDifficulty == l10n.quizDifficultyEasy ||
            englishDifficulty == l10n.quizDifficultyMedium ||
            englishDifficulty == l10n.quizDifficultyHard ||
            englishDifficulty == l10n.quizDifficultyExpert) {
          return englishDifficulty;
        }
        return englishDifficulty;
    }
  }

  String _getLocalizedQuizType(String englishQuizType, AppLocalizations l10n) {
    // Normalize the input to handle different formats from database
    final normalized = englishQuizType.toLowerCase().trim();

    if (normalized == 'all') {
      return l10n.quizTypeAll;
    }

    // Handle "Multiple Choice" or "multiple_choice" or "multiple choice"
    if (normalized == 'multiple choice' ||
        normalized == 'multiple_choice' ||
        normalized == 'multiplechoice') {
      return l10n.quizTypeMultipleChoice;
    }

    // Handle "True/False" or "true/false" or "true_false"
    if (normalized == 'true/false' ||
        normalized == 'true_false' ||
        normalized == 'true false') {
      return l10n.quizTypeTrueFalse;
    }

    // Handle "Fill in the Blank" or "fill_in_the_blank" or "fill in the blank"
    if (normalized == 'fill in the blank' ||
        normalized == 'fill_in_the_blank' ||
        normalized == 'fillintheblank') {
      return l10n.quizTypeFillInTheBlank;
    }

    // Fallback: try exact match for capitalized versions
    switch (englishQuizType) {
      case 'All':
        return l10n.quizTypeAll;
      case 'Multiple Choice':
        return l10n.quizTypeMultipleChoice;
      case 'True/False':
        return l10n.quizTypeTrueFalse;
      case 'Fill in the Blank':
        return l10n.quizTypeFillInTheBlank;
      default:
        return englishQuizType;
    }
  }

  /// Toggle filter visibility
  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  /// Reset all filters
  void _resetFilters() {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedQuizType = l10n.quizTypeAll;
      _selectedDifficulty = l10n.quizDifficultyAll;
      _dateFilter = l10n.allTime;
    });
    _applyFilters();
  }

  /// Build filter chip for difficulty and quiz type
  Widget _buildFilterChip(
    String label,
    String selectedValue,
    List<String> values,
    Function(String) onSelected,
  ) {
    final isSelected = selectedValue == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => onSelected(isSelected ? 'All' : label),
        backgroundColor: Colors.grey[200],
        selectedColor: AppColors.primary.withOpacity(0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Initialize date filters if not already done
    if (_dateFilters.isEmpty) {
      _dateFilters = [
        l10n.allTime,
        l10n.today,
        l10n.thisWeek,
        l10n.thisMonth,
        l10n.last3Months,
      ];
      // Update current filter to localized version if it's still in English
      if (_dateFilter == 'All Time' ||
          _dateFilter == 'Today' ||
          _dateFilter == 'This Week' ||
          _dateFilter == 'This Month' ||
          _dateFilter == 'Last 3 Months') {
        _dateFilter = _getLocalizedDateFilter(_dateFilter, l10n);
      }
    }

    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar with filter toggle
              Row(
                children: [
                  // Search field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.searchQuizHistory,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                  _applyFilters();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        _applyFilters();
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Filter toggle button
                  Container(
                    decoration: BoxDecoration(
                      color: _showFilters
                          ? AppColors.primary.withOpacity(0.15)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: _showFilters
                          ? Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            )
                          : null,
                    ),
                    child: IconButton(
                      icon: Badge(
                        isLabelVisible: () {
                          final englishQuizType =
                              _getEnglishQuizType(_selectedQuizType, l10n);
                          final englishDifficulty =
                              _getEnglishDifficulty(_selectedDifficulty, l10n);
                          final englishDateFilter =
                              _getEnglishDateFilter(_dateFilter, l10n);
                          return englishQuizType != 'All' ||
                              englishDifficulty != 'All' ||
                              englishDateFilter != 'All Time';
                        }(),
                        child: Icon(
                          Icons.filter_list,
                          color: _showFilters
                              ? AppColors.primary
                              : Colors.grey[700],
                        ),
                      ),
                      onPressed: _toggleFilters,
                      tooltip: l10n.toggleFilters,
                    ),
                  ),
                ],
              ),

              // Filters section (collapsible)
              if (_showFilters) ...[
                const SizedBox(height: 16),

                // Quiz type filter
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Difficulty label
                    Text(
                      l10n.difficultyLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Difficulty chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _difficulties
                            .map(
                              (difficulty) => _buildFilterChip(
                                difficulty,
                                _selectedDifficulty,
                                _difficulties,
                                (value) {
                                  setState(() {
                                    _selectedDifficulty = value;
                                  });
                                  _applyFilters();
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quiz type label
                    Text(
                      l10n.quizTypeLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quiz type chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quizTypes
                            .map(
                              (type) => _buildFilterChip(
                                type,
                                _selectedQuizType,
                                _quizTypes,
                                (value) {
                                  setState(() {
                                    _selectedQuizType = value;
                                  });
                                  _applyFilters();
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date range label
                    Text(
                      l10n.dateRange,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date range dropdown
                    DropdownButtonFormField<String>(
                      value: _dateFilter,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _dateFilters
                          .map(
                            (date) => DropdownMenuItem(
                              value: date,
                              child: Text(date),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _dateFilter = value;
                          });
                          _applyFilters();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Filter actions
                Builder(
                  builder: (context) {
                    final englishQuizType =
                        _getEnglishQuizType(_selectedQuizType, l10n);
                    final englishDifficulty =
                        _getEnglishDifficulty(_selectedDifficulty, l10n);
                    final englishDateFilter =
                        _getEnglishDateFilter(_dateFilter, l10n);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Only show reset button if filters are applied
                        if (englishQuizType != 'All' ||
                            englishDifficulty != 'All' ||
                            englishDateFilter != 'All Time')
                          TextButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.resetFilters),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        // Active filters display (when filters are collapsed)
        Builder(
          builder: (context) {
            final englishQuizType =
                _getEnglishQuizType(_selectedQuizType, l10n);
            final englishDifficulty =
                _getEnglishDifficulty(_selectedDifficulty, l10n);
            final englishDateFilter = _getEnglishDateFilter(_dateFilter, l10n);
            if (!_showFilters &&
                (englishQuizType != 'All' ||
                    englishDifficulty != 'All' ||
                    englishDateFilter != 'All Time')) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(l10n.activeFilters),
                      const SizedBox(width: 8),
                      if (englishDifficulty != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(_selectedDifficulty),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedDifficulty = l10n.quizDifficultyAll;
                              });
                              _applyFilters();
                            },
                            visualDensity: VisualDensity.compact,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      if (englishQuizType != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(_selectedQuizType),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedQuizType = l10n.quizTypeAll;
                              });
                              _applyFilters();
                            },
                            visualDensity: VisualDensity.compact,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      if (englishDateFilter != 'All Time')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(_dateFilter),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _dateFilter = l10n.allTime;
                              });
                              _applyFilters();
                            },
                            visualDensity: VisualDensity.compact,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: _resetFilters,
                        child: Text(l10n.clearAll),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Quiz history list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.warning,
                            size: 48,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.errorLoadingQuizHistory,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadQuizHistory,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.tryAgain),
                          ),
                        ],
                      ),
                    )
                  : _filteredAttempts.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadQuizHistory,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredAttempts.length,
                            itemBuilder: (context, index) {
                              final attempt = _filteredAttempts[index];
                              final quiz = attempt['quizzes'];
                              final isDeleting = attempt['_isDeleting'] == true;

                              return _buildAttemptCard(
                                  attempt, quiz, isDeleting);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  /// Build empty state widget when no quiz history found
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    final englishQuizType = _getEnglishQuizType(_selectedQuizType, l10n);
    final englishDifficulty = _getEnglishDifficulty(_selectedDifficulty, l10n);
    final englishDateFilter = _getEnglishDateFilter(_dateFilter, l10n);
    final isFiltered = _searchQuery.isNotEmpty ||
        englishDifficulty != 'All' ||
        englishQuizType != 'All' ||
        englishDateFilter != 'All Time';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_alt : Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            isFiltered ? l10n.noMatchingQuizAttempts : l10n.noQuizHistoryYet,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              isFiltered
                  ? l10n.tryAdjustingFiltersOrSearchTerms
                  : l10n.completeFirstQuizToSeeProgress,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 32),
          if (isFiltered)
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: Text(l10n.clearFilters),
            ),
        ],
      ),
    );
  }

  /// Build quiz attempt card
  Widget _buildAttemptCard(dynamic attempt, dynamic quiz, bool isDeleting) {
    final l10n = AppLocalizations.of(context)!;

    // Quiz details
    final quizTitle = quiz?['title'] ?? l10n.untitledQuiz;
    final quizType = quiz?['quiz_type'] ?? 'Unknown';
    final difficulty = quiz?['difficulty'] ?? 'Unknown';
    final quizId = quiz?['id'];

    // Attempt details
    final score = attempt['score'] ?? 0;
    final totalQuestions = attempt['total_questions'] ?? 0;
    final percentage = totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;
    final createdAt = DateTime.parse(attempt['created_at']);
    final timeTaken = attempt['time_taken'] ?? 0;

    // Format time taken
    final minutes = (timeTaken / 60).floor();
    final seconds = timeTaken % 60;
    final formattedTime = '${minutes}m ${seconds}s';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      elevation: 1,
      child: InkWell(
        onTap: () {
          if (!isDeleting) {
            // Navigate to quiz attempt details
            context.go('/quiz-review/${attempt['id']}');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Expanded(
                    child: Text(
                      quizTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Popup menu
                  if (!isDeleting)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'view') {
                          context.go('/quiz-review/${attempt['id']}');
                        } else if (value == 'retake' && quizId != null) {
                          context.go('/quiz/$quizId');
                        } else if (value == 'delete') {
                          _deleteQuizAttempt(attempt);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              const Icon(Icons.visibility),
                              const SizedBox(width: 8),
                              Text(l10n.viewDetails),
                            ],
                          ),
                        ),
                        if (quizId != null)
                          PopupMenuItem(
                            value: 'retake',
                            child: Row(
                              children: [
                                const Icon(Icons.replay),
                                const SizedBox(width: 8),
                                Text(l10n.retakeQuiz),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                l10n.delete,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Date and time taken
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    formatDate(createdAt, context),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    formattedTime,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Score information
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.scoreFormat(score, totalQuestions),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _getScoreColor(percentage),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress bar
              LinearPercentIndicator(
                percent: percentage > 100 ? 1.0 : percentage / 100,
                lineHeight: 12,
                animation: true,
                animationDuration: 500,
                backgroundColor: Colors.grey[200],
                progressColor: _getScoreColor(percentage),
                barRadius: const Radius.circular(8),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // Difficulty and quiz type badges
              Row(
                children: [
                  _buildBadge(
                    _getLocalizedDifficulty(difficulty, l10n),
                    Icons.fitness_center,
                    _getDifficultyColor(difficulty),
                  ),
                  const SizedBox(width: 8),
                  _buildBadge(
                    _getLocalizedQuizType(quizType, l10n),
                    Icons.quiz,
                    AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isDeleting
                          ? null
                          : () {
                              context.go(
                                '/quiz-review/${attempt['id']}',
                              );
                            },
                      icon: const Icon(Icons.visibility),
                      label: Text(l10n.viewDetails),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isDeleting || quizId == null
                          ? null
                          : () {
                              context.go('/quiz/$quizId');
                            },
                      icon: const Icon(Icons.replay),
                      label: Text(l10n.retakeQuiz),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build badge widget for difficulty and quiz type
  Widget _buildBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Get score color based on percentage
  Color _getScoreColor(double percentage) {
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 60) {
      return Colors.amber.shade700;
    } else if (percentage >= 40) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Get difficulty color
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      case 'expert':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
