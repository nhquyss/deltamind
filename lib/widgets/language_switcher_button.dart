import 'package:deltamind/core/locale/locale_controller.dart';
import 'package:deltamind/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Language switcher button widget
/// Can be used in any page, including auth pages
class LanguageSwitcherButton extends ConsumerWidget {
  const LanguageSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final localeState = ref.watch(localeControllerProvider);
    final currentLocale = localeState.locale;

    return PopupMenuButton<Locale>(
      icon: Icon(
        Icons.language,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.primary,
      ),
      tooltip: l10n.language,
      onSelected: (Locale locale) {
        ref.read(localeControllerProvider.notifier).setLocale(locale);
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<Locale>(
          value: const Locale('en', ''),
          child: Row(
            children: [
              if (currentLocale.languageCode == 'en')
                const Icon(Icons.check, size: 20, color: AppColors.primary)
              else
                const SizedBox(width: 20),
              const SizedBox(width: 8),
              Text(l10n.english),
            ],
          ),
        ),
        PopupMenuItem<Locale>(
          value: const Locale('vi', ''),
          child: Row(
            children: [
              if (currentLocale.languageCode == 'vi')
                const Icon(Icons.check, size: 20, color: AppColors.primary)
              else
                const SizedBox(width: 20),
              const SizedBox(width: 8),
              Text(l10n.vietnamese),
            ],
          ),
        ),
      ],
    );
  }
}
