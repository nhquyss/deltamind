import 'package:deltamind/core/routing/app_router.dart';
import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/core/utils/formatters.dart';
import 'package:deltamind/features/quiz/quiz_controller.dart';
import 'package:deltamind/features/quiz/quiz_history_tab.dart';
import 'package:deltamind/services/quiz_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Quiz list page with tabbed interface for Quizzes and History
class QuizListPage extends ConsumerStatefulWidget {
  /// The initial tab index to show (0 for Quizzes, 1 for History)
  final int initialTabIndex;

  /// Creates a QuizListPage with the given initial tab index
  const QuizListPage({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  ConsumerState<QuizListPage> createState() => _QuizListPageState();
}

class _QuizListPageState extends ConsumerState<QuizListPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  List<Quiz> _quizzes = [];
  String _searchQuery = '';
  String _selectedQuizType = 'All'; // Will be localized in build
  String _selectedDifficulty = 'All'; // Will be localized in build
  bool _showFilters = false;

  // Tab controller
  late TabController _tabController;

  // For filtering
  final TextEditingController _searchController = TextEditingController();

  // Helper methods to map between localized and English values
  String _getEnglishQuizType(String localizedType, AppLocalizations l10n) {
    if (localizedType == l10n.quizTypeAll) return 'All';
    if (localizedType == l10n.quizTypeMultipleChoice) return 'Multiple Choice';
    if (localizedType == l10n.quizTypeTrueFalse) return 'True/False';
    if (localizedType == l10n.quizTypeFillInTheBlank)
      return 'Fill in the Blank';
    return localizedType; // Fallback to original if not found
  }

  String _getEnglishDifficulty(
      String localizedDifficulty, AppLocalizations l10n) {
    if (localizedDifficulty == l10n.quizDifficultyAll) return 'All';
    if (localizedDifficulty == l10n.quizDifficultyEasy) return 'Easy';
    if (localizedDifficulty == l10n.quizDifficultyMedium) return 'Medium';
    if (localizedDifficulty == l10n.quizDifficultyHard) return 'Hard';
    if (localizedDifficulty == l10n.quizDifficultyExpert) return 'Expert';
    return localizedDifficulty; // Fallback to original if not found
  }

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 2 tabs
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    // Delay loading quizzes slightly to ensure the widget is fully initialized
    Future.microtask(() => _loadQuizzes());

    // Add listener to tab controller to handle tab changes
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didUpdateWidget(QuizListPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if initialTabIndex has changed due to navigation
    final extra = GoRouterState.of(context).extra;
    if (extra != null && extra is int && extra != _tabController.index) {
      _tabController.animateTo(extra);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  /// Handle tab change to refresh content
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // Clear search and filters when switching tabs
      // Reset to 'All' - will be localized in build method
      setState(() {
        _searchQuery = '';
        _searchController.clear();
        _selectedQuizType = 'All';
        _selectedDifficulty = 'All';
        _showFilters = false;
      });

      // Reload appropriate content based on selected tab
      if (_tabController.index == 0) {
        _loadQuizzes();
      } else {
        // History tab handles its own loading
      }
    }
  }

  /// Load quizzes from database
  Future<void> _loadQuizzes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use try-catch for the controller interaction
      try {
        await ref.read(quizControllerProvider.notifier).loadUserQuizzes();
      } catch (e) {
        _safeHandleError('loading quizzes from controller', e);
        return;
      }
    } catch (e) {
      _safeHandleError('loading quizzes', e);
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Delete a quiz
  Future<void> _deleteQuiz(String quizId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteQuiz),
        content: Text(l10n.deleteQuizConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      try {
        final success =
            await ref.read(quizControllerProvider.notifier).deleteQuiz(quizId);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.quizDeletedSuccessfully),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        _safeHandleError('deleting quiz', e);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Safe error handler for provider operations
  void _safeHandleError(String operation, Object error) {
    if (mounted) {
      debugPrint('Error during $operation: $error');
      setState(() {
        _errorMessage = 'Error: $operation failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Toggle filters visibility
  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  /// Reset all filters
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedQuizType = 'All'; // Will be localized in build
      _selectedDifficulty = 'All'; // Will be localized in build
    });
  }

  /// Build filter chip
  Widget _buildFilterChip(
    String label,
    String selectedValue,
    List<String> options,
    Function(String) onSelected,
  ) {
    final isSelected = label == selectedValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(isSelected ? 'All' : label),
        backgroundColor: Colors.grey[200],
        selectedColor: AppColors.primary.withOpacity(0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Build empty state widget
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    final isFiltered = _searchQuery.isNotEmpty ||
        _selectedDifficulty != l10n.quizDifficultyAll ||
        _selectedQuizType != l10n.quizTypeAll;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_list_off : Icons.quiz,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            isFiltered ? l10n.noMatchingQuizzes : l10n.noQuizzesAvailable,
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
                  ? l10n.adjustFiltersOrSearch
                  : l10n.createYourFirstQuizHere,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 32),
          if (isFiltered)
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_list_off),
              label: Text(l10n.clearFiltersAction),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                context.go('/create-quiz');
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.createQuiz),
            ),
        ],
      ),
    );
  }

  /// Build quiz list
  Widget _buildQuizList() {
    return ListView.builder(
      itemCount: _quizzes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final quiz = _quizzes[index];

        // Create display description without repetition
        final l10n = AppLocalizations.of(context)!;
        String displayDescription = l10n.generatedQuiz;
        if (quiz.description != null && quiz.description!.isNotEmpty) {
          if (quiz.description!.toLowerCase().contains("elon")) {
            displayDescription = l10n.generatedQuizBasedOnFile("elon.png");
          } else if (quiz.description!.toLowerCase().contains("poem")) {
            displayDescription = l10n.generatedQuizBasedOnContent;
          } else {
            displayDescription = l10n.generatedQuizBasedOnContent;
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side:
                BorderSide(color: AppColors.primary.withOpacity(0.2), width: 1),
          ),
          elevation: 1,
          child: InkWell(
            onTap: () {
              context.go('/quiz/${quiz.id}');
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and menu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          quiz.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteQuiz(quiz.id);
                          }
                        },
                        itemBuilder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          return [
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
                          ];
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description - fixed to avoid duplication
                  Text(
                    displayDescription,
                    style: TextStyle(color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Date display matching history tab
                  if (quiz.createdAt != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          formatDate(quiz.createdAt!, context),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quiz type and difficulty badges
                  Row(
                    children: [
                      _buildBadge(quiz.quizType, Icons.quiz, AppColors.primary),
                      const SizedBox(width: 8),
                      _buildBadge(quiz.difficulty, Icons.fitness_center,
                          _getDifficultyColor(quiz.difficulty)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Start Quiz button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.go('/quiz/${quiz.id}');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(l10n.startQuiz),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Get color for difficulty
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green.shade600;
      case 'medium':
        return Colors.orange.shade600;
      case 'hard':
        return Colors.red.shade600;
      case 'expert':
        return Colors.purple.shade600;
      default:
        return AppColors.primary;
    }
  }

  /// Build badge for quiz type and difficulty
  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      constraints: const BoxConstraints(maxWidth: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Initialize filter values with localized strings if they're still in English
    if (_selectedQuizType == 'All') {
      _selectedQuizType = l10n.quizTypeAll;
    }
    if (_selectedDifficulty == 'All') {
      _selectedDifficulty = l10n.quizDifficultyAll;
    }

    // Use try-catch for the controller interaction
    try {
      final quizState = ref.watch(quizControllerProvider);
      _quizzes = quizState.userQuizzes;

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        _quizzes = _quizzes
            .where(
              (quiz) => quiz.title.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
            )
            .toList();
      }

      // Apply type filter
      final englishQuizType = _getEnglishQuizType(_selectedQuizType, l10n);
      if (englishQuizType != 'All') {
        _quizzes =
            _quizzes.where((quiz) => quiz.quizType == englishQuizType).toList();
      }

      // Apply difficulty filter
      final englishDifficulty =
          _getEnglishDifficulty(_selectedDifficulty, l10n);
      if (englishDifficulty != 'All') {
        _quizzes = _quizzes
            .where((quiz) => quiz.difficulty == englishDifficulty)
            .toList();
      }
    } catch (e) {
      debugPrint('Error watching quiz controller: $e');
      if (_errorMessage == null) {
        _errorMessage = 'Error loading quizzes: $e';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quizzes),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.quizzesTab, icon: const Icon(Icons.quiz)),
            Tab(text: l10n.historyTab, icon: const Icon(Icons.history)),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () {
                    if (_tabController.index == 0) {
                      _loadQuizzes();
                    }
                  },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Quizzes Tab
          SafeArea(
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: l10n.searchQuizzes,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
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
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          icon: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.filter_list,
                                color: _showFilters
                                    ? AppColors.primary
                                    : Colors.grey[700],
                              ),
                              if (_selectedQuizType != l10n.quizTypeAll ||
                                  _selectedDifficulty != l10n.quizDifficultyAll)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: _toggleFilters,
                          tooltip: l10n.toggleFilters,
                        ),
                      ),
                    ],
                  ),
                ),

                // Filters section (collapsible)
                if (_showFilters) ...[
                  const SizedBox(height: 16),

                  // Quiz type filter
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 0.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quiz type label
                        Text(
                          l10n.quizTypeLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quiz type chips
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            final List<String> quizTypes = [
                              l10n.quizTypeAll,
                              l10n.quizTypeMultipleChoice,
                              l10n.quizTypeTrueFalse,
                              l10n.quizTypeFillInTheBlank,
                            ];
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: quizTypes
                                    .map(
                                      (type) => _buildFilterChip(
                                        type,
                                        _selectedQuizType,
                                        quizTypes,
                                        (value) {
                                          setState(() {
                                            _selectedQuizType = value;
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Difficulty filter
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Column(
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
                        const SizedBox(height: 12),

                        // Difficulty chips
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            final List<String> difficulties = [
                              l10n.quizDifficultyAll,
                              l10n.quizDifficultyEasy,
                              l10n.quizDifficultyMedium,
                              l10n.quizDifficultyHard,
                              l10n.quizDifficultyExpert,
                            ];
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: difficulties
                                    .map(
                                      (difficulty) => _buildFilterChip(
                                        difficulty,
                                        _selectedDifficulty,
                                        difficulties,
                                        (value) {
                                          setState(() {
                                            _selectedDifficulty = value;
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Filter actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Only show reset button if filters are applied
                      if (_selectedQuizType != l10n.quizTypeAll ||
                          _selectedDifficulty != l10n.quizDifficultyAll)
                        TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.resetFilters),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ],

                // Active filters display (when filters are collapsed)
                if (!_showFilters &&
                    (_selectedQuizType != l10n.quizTypeAll ||
                        _selectedDifficulty != l10n.quizDifficultyAll))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          l10n.activeFilters,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedQuizType != l10n.quizTypeAll)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(_selectedQuizType),
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.1),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() {
                                  _selectedQuizType = l10n.quizTypeAll;
                                });
                              },
                              visualDensity: VisualDensity.compact,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                            ),
                          ),
                        if (_selectedDifficulty != l10n.quizDifficultyAll)
                          Chip(
                            label: Text(_selectedDifficulty),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedDifficulty = l10n.quizDifficultyAll;
                              });
                            },
                            visualDensity: VisualDensity.compact,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: _resetFilters,
                          child: Text(l10n.clearAll),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Quiz list or empty state
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(child: Text(_errorMessage!))
                          : _quizzes.isEmpty
                              ? _buildEmptyState()
                              : _buildQuizList(),
                ),
              ],
            ),
          ),

          // History Tab
          const SafeArea(child: QuizHistoryTab()),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.createQuiz),
              tooltip: l10n.createQuiz,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
