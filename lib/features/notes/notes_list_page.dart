import 'package:deltamind/core/routing/app_router.dart';
import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/core/utils/formatters.dart';
import 'package:deltamind/features/notes/notes_controller.dart';
import 'package:deltamind/features/notes/widgets/rich_text_editor.dart';
import 'package:deltamind/models/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page to display a list of notes
class NotesListPage extends ConsumerStatefulWidget {
  /// Creates a [NotesListPage]
  const NotesListPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends ConsumerState<NotesListPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load notes and tags when page is opened
    Future.microtask(() {
      ref.read(notesControllerProvider.notifier).loadNotes();
      ref.read(notesControllerProvider.notifier).loadTags();
    });

    // Listen for search changes and update the provider
    _searchController.addListener(() {
      ref
          .read(notesControllerProvider.notifier)
          .setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notesState = ref.watch(notesControllerProvider);
    final theme = Theme.of(context);

    // Get filtered notes based on current state
    final displayedNotes = notesState.filteredNotes;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notes),
        actions: [
          // Toggle grid/list view
          IconButton(
            icon: Icon(
              notesState.isGridView ? Icons.view_list : Icons.grid_view,
            ),
            onPressed: () =>
                ref.read(notesControllerProvider.notifier).toggleViewType(),
            tooltip: notesState.isGridView ? l10n.listView : l10n.gridView,
          ),

          // Clear all filters
          if (notesState.selectedTags.isNotEmpty ||
              notesState.searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () {
                ref.read(notesControllerProvider.notifier).clearFilters();
                _searchController.clear();
                ref.read(notesControllerProvider.notifier).loadNotes();
              },
              tooltip: l10n.clearFilters,
            ),

          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(notesControllerProvider.notifier).loadNotes();
              ref.read(notesControllerProvider.notifier).loadTags();
            },
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchNotes,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(notesControllerProvider.notifier)
                              .loadNotes();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onSubmitted: (_) =>
                  ref.read(notesControllerProvider.notifier).loadNotes(),
            ),
          ),

          // Tags horizontal list
          if (notesState.availableTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: notesState.availableTags.length,
                  itemBuilder: (context, index) {
                    final tag = notesState.availableTags[index];
                    final isSelected = notesState.selectedTags.contains(tag);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          ref
                              .read(notesControllerProvider.notifier)
                              .toggleTag(tag);
                          ref
                              .read(notesControllerProvider.notifier)
                              .loadNotes();
                        },
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        checkmarkColor: AppColors.primary,
                        labelStyle: const TextStyle(fontSize: 13),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Notes list
          Expanded(child: _buildNotesList(displayedNotes, notesState)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(AppRoutes.createNote),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNotesList(List<Note> notes, NotesState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${l10n.error}: ${state.errorMessage}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(notesControllerProvider.notifier).loadNotes(),
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.note_alt_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              state.searchQuery.isNotEmpty || state.selectedTags.isNotEmpty
                  ? l10n.noNotesMatchYourFilters
                  : l10n.youDontHaveAnyNotesYet,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.createNote),
              icon: const Icon(Icons.add),
              label: Text(l10n.createNote),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notesControllerProvider.notifier).loadNotes(),
      child: state.isGridView
          ? GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio:
                    0.65, // Reduced from 0.8 to give more height to cards
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return _buildNoteCard(note, context);
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return _buildNoteCard(note, context);
              },
            ),
    );
  }

  Widget _buildNoteCard(Note note, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final formattedDate = note.updatedAt != null
        ? '${l10n.updated}${formatDate(note.updatedAt!, context)}'
        : '';

    // Note background color
    Color? backgroundColor;
    if (note.color != null) {
      switch (note.color) {
        case 'red':
          backgroundColor = Colors.red[100];
          break;
        case 'orange':
          backgroundColor = Colors.orange[100];
          break;
        case 'yellow':
          backgroundColor = Colors.yellow[100];
          break;
        case 'green':
          backgroundColor = Colors.green[100];
          break;
        case 'teal':
          backgroundColor = Colors.teal[100];
          break;
        case 'blue':
          backgroundColor = Colors.blue[100];
          break;
        case 'purple':
          backgroundColor = Colors.purple[100];
          break;
        case 'pink':
          backgroundColor = Colors.pink[100];
          break;
        case 'gray':
          backgroundColor = Colors.grey[200];
          break;
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => context.go('/notes/${note.id}'),
        child: Stack(
          children: [
            // Note content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: theme.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) => _handleNoteAction(value, note),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(note.isPinned
                                ? AppLocalizations.of(context)!.unpin
                                : AppLocalizations.of(context)!.pin),
                          ),
                          PopupMenuItem(
                            value: 'color',
                            child:
                                Text(AppLocalizations.of(context)!.changeColor),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(AppLocalizations.of(context)!.delete),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (note.content != null && note.content!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: RichTextViewer(
                        content: note.content,
                        maxHeight: 100,
                      ),
                    ),
                  // Tags inside card - commented out to fix overflow
                  // if (note.tags.isNotEmpty)
                  //   Padding(
                  //     padding: const EdgeInsets.only(top: 8.0),
                  //     child: Wrap(
                  //       spacing: 4,
                  //       runSpacing: 4,
                  //       children: note.tags
                  //           .map(
                  //             (tag) => Chip(
                  //               label: Text(
                  //                 tag,
                  //                 style: const TextStyle(fontSize: 10),
                  //               ),
                  //               materialTapTargetSize:
                  //                   MaterialTapTargetSize.shrinkWrap,
                  //               visualDensity: VisualDensity.compact,
                  //               padding: EdgeInsets.zero,
                  //               labelPadding:
                  //                   const EdgeInsets.symmetric(horizontal: 4),
                  //             ),
                  //           )
                  //           .toList(),
                  //     ),
                  //   ),
                  if (formattedDate.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),

            // Pinned indicator
            if (note.isPinned)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Icon(
                    Icons.push_pin,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleNoteAction(String action, Note note) async {
    final notesController = ref.read(notesControllerProvider.notifier);

    switch (action) {
      case 'pin':
        await notesController.togglePin(note.id);
        break;

      case 'color':
        _showColorPicker(note);
        break;

      case 'delete':
        _confirmDelete(note);
        break;
    }
  }

  void _showColorPicker(Note note) {
    final colors = {
      'Default': null,
      'Red': 'red',
      'Orange': 'orange',
      'Yellow': 'yellow',
      'Green': 'green',
      'Teal': 'teal',
      'Blue': 'blue',
      'Purple': 'purple',
      'Pink': 'pink',
      'Gray': 'gray',
    };

    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chooseColor),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.entries.map((entry) {
            Color displayColor = Colors.white;
            switch (entry.value) {
              case 'red':
                displayColor = Colors.red[100]!;
                break;
              case 'orange':
                displayColor = Colors.orange[100]!;
                break;
              case 'yellow':
                displayColor = Colors.yellow[100]!;
                break;
              case 'green':
                displayColor = Colors.green[100]!;
                break;
              case 'teal':
                displayColor = Colors.teal[100]!;
                break;
              case 'blue':
                displayColor = Colors.blue[100]!;
                break;
              case 'purple':
                displayColor = Colors.purple[100]!;
                break;
              case 'pink':
                displayColor = Colors.pink[100]!;
                break;
              case 'gray':
                displayColor = Colors.grey[200]!;
                break;
            }

            final isSelected = (note.color == null && entry.value == null) ||
                (note.color != null && note.color == entry.value);

            return InkWell(
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(notesControllerProvider.notifier)
                    .updateNoteColor(note.id, entry.value);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: displayColor,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: isSelected ? const Icon(Icons.check, size: 20) : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Note note) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteNote),
        content: Text(l10n.deleteNoteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(notesControllerProvider.notifier).deleteNote(note.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
