import 'package:deltamind/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// A scaffold with a bottom navigation bar
class ScaffoldWithNavBar extends StatefulWidget {
  /// The child widget to display
  final Widget child;

  /// Creates a [ScaffoldWithNavBar]
  const ScaffoldWithNavBar({Key? key, required this.child}) : super(key: key);

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    if (location.startsWith(AppRoutes.dashboard)) {
      return 0;
    }
    if (location.startsWith(AppRoutes.quizList)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.notesList)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.flashcardsList)) {
      return 3;
    }
    if (location.startsWith(AppRoutes.profile)) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
        break;
      case 1:
        context.go(AppRoutes.quizList);
        break;
      case 2:
        context.go(AppRoutes.notesList);
        break;
      case 3:
        context.go(AppRoutes.flashcardsList);
        break;
      case 4:
        context.go(AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.quiz),
            label: l10n.quizzes,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.notes),
            label: l10n.notes,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.flip_to_back),
            label: l10n.flashcards,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}
