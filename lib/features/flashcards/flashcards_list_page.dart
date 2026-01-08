import 'package:deltamind/core/routing/app_router.dart';
import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/models/flashcard.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:deltamind/services/flashcard_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// FlashcardsListPage displays all flashcard decks
class FlashcardsListPage extends StatefulWidget {
  /// Creates a FlashcardsListPage
  const FlashcardsListPage({Key? key}) : super(key: key);

  @override
  State<FlashcardsListPage> createState() => _FlashcardsListPageState();
}

class _FlashcardsListPageState extends State<FlashcardsListPage> {
  bool _isLoading = true;
  List<FlashcardDeck> _decks = [];
  List<FlashcardDeck> _filteredDecks = [];
  String? _errorMessage;

  // Search and filter variables
  String _searchQuery = '';
  String _selectedSourceType = 'All';
  bool _showFilters = false;
  final TextEditingController _searchController = TextEditingController();

// // Source type filter options
//   final List<String> _sourceTypes = [
//     'All',
//     'PDF',
//     'Document',
//     'Text',
//     'Image',
//   ];
  // Source type filter options - will be initialized in build method
  List<String> _sourceTypes = [];

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final decks = await FlashcardService.getUserDecks();
      setState(() {
        _decks = decks;
        _applyFilters(); // Apply filters after loading decks
        _isLoading = false;
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.failedToLoadFlashcardDecks(e.toString());
      });
    }
  }

  /// Apply search and source type filters
  void _applyFilters() {
    final l10n = AppLocalizations.of(context)!;
    List<FlashcardDeck> result = _decks;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((deck) =>
              deck.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (deck.description != null &&
                  deck.description!
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase())))
          .toList();
    }

    // Apply source type filter
    if (_selectedSourceType != l10n.sourceTypeAll) {
      result = result.where((deck) {
        if (deck.sourceType == null) return false;

        final sourceType = deck.sourceType!.toLowerCase();
        final selectedType = _selectedSourceType.toLowerCase();
        if (selectedType == l10n.sourceTypePdf.toLowerCase()) {
          return sourceType.contains('pdf');
        } else if (selectedType == l10n.sourceTypeDocument.toLowerCase()) {
          return sourceType.contains('doc');
        } else if (selectedType == l10n.sourceTypeText.toLowerCase()) {
          return sourceType.contains('txt');
        } else if (selectedType == l10n.sourceTypeImage.toLowerCase()) {
          return sourceType.contains('png') ||
              sourceType.contains('jpg') ||
              sourceType.contains('image');
        }
        return true;
      }).toList();
    }

    setState(() {
      _filteredDecks = result;
    });
  }

  /// Toggle filters visibility
  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  /// Reset all filters
  void _resetFilters() {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSourceType = l10n.sourceTypeAll;
      _applyFilters();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Initialize source types if not already done
    if (_sourceTypes.isEmpty) {
      _sourceTypes = [
        l10n.sourceTypeAll,
        l10n.sourceTypePdf,
        l10n.sourceTypeDocument,
        l10n.sourceTypeText,
        l10n.sourceTypeImage,
      ];
      // Initialize selected source type
      if (_selectedSourceType == 'All') {
        _selectedSourceType = l10n.sourceTypeAll;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.flashcards),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsFill.plusCircle),
            onPressed: () => context.push(AppRoutes.createFlashcardDeck),
            tooltip: l10n.createNewDeck,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDecks,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDecks,
        child: Column(
          children: [
            // Search bar and filter button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.searchFlashcards,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _applyFilters();
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
                          _applyFilters();
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
                          if (_selectedSourceType != 'All')
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

              // Source type filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source type label
                    Text(
                      l10n.sourceType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Source type chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _sourceTypes
                            .map(
                              (type) => _buildFilterChip(
                                type,
                                _selectedSourceType,
                                _sourceTypes,
                                (value) {
                                  setState(() {
                                    _selectedSourceType = value;
                                    _applyFilters();
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filter actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Only show reset button if filters are applied
                    if (_selectedSourceType != l10n.sourceTypeAll)
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
              ),
            ],

            // Active filters display (when filters are collapsed)
            if (!_showFilters && _selectedSourceType != l10n.sourceTypeAll)
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
                    if (_selectedSourceType != l10n.sourceTypeAll)
                      Chip(
                        label: Text(_selectedSourceType),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _selectedSourceType = l10n.sourceTypeAll;
                            _applyFilters();
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

            // Main content (deck list or loading indicator)
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.createFlashcardDeck),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDecks,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.stackSimple,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noFlashcardDecksYet,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.createYourFirstDeckToGetStarted,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.createFlashcardDeck),
              icon: const Icon(Icons.add),
              label: Text(l10n.createDeck),
            ),
          ],
        ),
      );
    }

    // Show empty state if filtered decks is empty
    if (_filteredDecks.isEmpty) {
      final isFiltered =
          _searchQuery.isNotEmpty || _selectedSourceType != l10n.sourceTypeAll;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered
                  ? Icons.filter_list_off
                  : PhosphorIconsRegular.stackSimple,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? l10n.noMatchingFlashcardDecks
                  : l10n.noFlashcardDecks,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? l10n.tryAdjustingFiltersOrSearchTermsFlashcards
                  : l10n.createYourFirstDeckToGetStarted,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isFiltered)
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_list_off),
                label: Text(l10n.clearFilters),
              )
            else
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.createFlashcardDeck),
                icon: const Icon(Icons.add),
                label: Text(l10n.createDeck),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _filteredDecks.length,
      itemBuilder: (context, index) {
        final deck = _filteredDecks[index];
        return _buildDeckCard(deck);
      },
    );
  }

  Widget _buildDeckCard(FlashcardDeck deck) {
    final l10n = AppLocalizations.of(context)!;
    // Determine card color based on source type
    Color cardColor = Colors.blue.shade50;
    IconData sourceIcon = PhosphorIconsRegular.stackSimple;

    if (deck.sourceType != null) {
      final sourceType = deck.sourceType!.toLowerCase();
      if (sourceType.contains('pdf')) {
        cardColor = Colors.red.shade50;
        sourceIcon = PhosphorIconsRegular.filePdf;
      } else if (sourceType.contains('doc')) {
        cardColor = Colors.blue.shade50;
        sourceIcon = PhosphorIconsRegular.fileDoc;
      } else if (sourceType.contains('txt')) {
        cardColor = Colors.grey.shade50;
        sourceIcon = PhosphorIconsRegular.fileTxt;
      } else if (sourceType.contains('image') ||
          sourceType.contains('png') ||
          sourceType.contains('jpg')) {
        cardColor = Colors.green.shade50;
        sourceIcon = PhosphorIconsRegular.image;
      }
    }

    return Hero(
      tag: 'deck-${deck.id}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16.0),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => context.push('/flashcards/${deck.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cardColor.withOpacity(0.3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(sourceIcon, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          deck.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (deck.description != null && deck.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      deck.description!,
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsRegular.cards,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.cardsCount(deck.cardCount),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (deck.sourceName != null &&
                          deck.sourceName!.isNotEmpty)
                        Flexible(
                          child: Text(
                            deck.sourceName!,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Action buttons
                Divider(height: 1, color: Colors.grey[300]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/flashcards/${deck.id}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.edit),
                            ],
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(width: 1, color: Colors.grey[300]),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            context.push('/flashcards/${deck.id}/view'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIconsRegular.play,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                l10n.study,
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
