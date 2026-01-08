import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/services/learning_path_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Dialog to generate a new AI learning path
class GeneratePathDialog extends StatefulWidget {
  const GeneratePathDialog({Key? key}) : super(key: key);

  @override
  State<GeneratePathDialog> createState() => _GeneratePathDialogState();
}

class _GeneratePathDialogState extends State<GeneratePathDialog> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _learningGoalsController = TextEditingController();
  // Commented out - not currently used but kept for future use
  // final _timeCommitmentController = TextEditingController();
  // final _focusAreasController = TextEditingController();
  // final _suggestedTagsController = TextEditingController();
  String _knowledgeLevel = 'beginner';
  String _learningStyle = 'balanced';
  bool _isAdvancedOptionsVisible = false;
  bool _isGenerating = false;
  String? _errorMessage;

  final List<String> _knowledgeLevels = [
    'beginner',
    'intermediate',
    'advanced'
  ];
  final List<String> _learningStyles = [
    'balanced',
    'visual',
    'practical',
    'theoretical',
    // Commented out - merged into 'practical' to simplify options
    // 'interactive',
  ];

  @override
  void dispose() {
    _topicController.dispose();
    _learningGoalsController.dispose();
    // Commented out - not currently used but kept for future use
    // _timeCommitmentController.dispose();
    // _focusAreasController.dispose();
    // _suggestedTagsController.dispose();
    super.dispose();
  }

  /// Generate a learning path
  Future<void> _generatePath() async {
    if (!_formKey.currentState!.validate()) return;

    final topic = _topicController.text.trim();
    final learningGoals = _learningGoalsController.text.trim();
    // Commented out - not currently used but kept for future use
    // final timeCommitment = _timeCommitmentController.text.trim();
    // final focusAreas = _focusAreasController.text.trim().isNotEmpty
    //     ? _focusAreasController.text
    //         .trim()
    //         .split(',')
    //         .map((e) => e.trim())
    //         .toList()
    //     : null;
    // final suggestedTags = _suggestedTagsController.text.trim().isNotEmpty
    //     ? _suggestedTagsController.text
    //         .trim()
    //         .split(',')
    //         .map((e) => e.trim())
    //         .toList()
    //     : null;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // Get current locale and map to language name
      final locale = Localizations.localeOf(context);
      final language = _getLanguageName(locale);

      // First, generate the learning path content using AI
      final generatedPath = await LearningPathService.generateLearningPath(
        topic: topic,
        knowledgeLevel: _knowledgeLevel,
        learningGoals: learningGoals.isNotEmpty ? learningGoals : null,
        learningStyle: _learningStyle,
        language: language,
        // Commented out - not currently used but kept for future use
        // timeCommitment: timeCommitment.isNotEmpty ? timeCommitment : null,
        // focusAreas: focusAreas,
        // suggestedTags: suggestedTags,
      );

      if (!mounted) return;

      // Check if this is a fallback path
      bool isFallback = false;
      if (generatedPath['is_fallback'] == true ||
          generatedPath['additional_notes'] ==
              'Created as fallback due to AI generation error' ||
          (generatedPath['modules'] != null &&
              generatedPath['modules'] is List &&
              generatedPath['modules'].isNotEmpty &&
              generatedPath['modules'][0]['additional_notes'] ==
                  'Created as fallback due to AI generation error')) {
        isFallback = true;
      }

      // Create the learning path in the database
      await LearningPathService.createFromGeneratedPath(
        generatedPath,
        language: language,
      );

      if (!mounted) return;

      // Close dialog with success
      Navigator.of(context).pop(true);

      // If it was a fallback path, show a notification
      if (isFallback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .createdABasicLearningPathAIGenerationHadIssuesYouMayWantToEditThisPathLater,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog header
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.roadHorizon(PhosphorIconsStyle.fill),
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.generateAILearningPath,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 24,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Topic input
                TextFormField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    labelText: l10n.learningTopic,
                    hintText: l10n.learningTopicHint,
                    prefixIcon: Icon(
                        PhosphorIcons.lightbulb(PhosphorIconsStyle.regular)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.pleaseEnterATopic;
                    }
                    if (value.trim().length < 3) {
                      return l10n.topicIsTooShort;
                    }
                    return null;
                  },
                  enabled: !_isGenerating,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Knowledge level dropdown
                DropdownButtonFormField<String>(
                  value: _knowledgeLevel,
                  decoration: InputDecoration(
                    labelText: l10n.knowledgeLevel,
                    prefixIcon: Icon(
                      PhosphorIcons.graduationCap(PhosphorIconsStyle.regular),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                  ),
                  items: _knowledgeLevels
                      .map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(
                              level == 'beginner'
                                  ? l10n.beginner
                                  : level == 'intermediate'
                                      ? l10n.intermediate
                                      : l10n.advanced,
                            ),
                          ))
                      .toList(),
                  onChanged: _isGenerating
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _knowledgeLevel = value;
                            });
                          }
                        },
                ),

                const SizedBox(height: 16),

                // Advanced options toggle
                GestureDetector(
                  onTap: _isGenerating
                      ? null
                      : () {
                          setState(() {
                            _isAdvancedOptionsVisible =
                                !_isAdvancedOptionsVisible;
                          });
                        },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isAdvancedOptionsVisible
                              ? PhosphorIcons.caretDown(
                                  PhosphorIconsStyle.regular)
                              : PhosphorIcons.caretRight(
                                  PhosphorIconsStyle.regular),
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.advancedOptions,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _isAdvancedOptionsVisible ? l10n.hide : l10n.show,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Advanced options section
                _buildAdvancedOptions(),

                const SizedBox(height: 24),

                // Generate button
                ElevatedButton(
                  onPressed: _isGenerating ? null : _generatePath,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  ),
                  child: _isGenerating
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(l10n.generating),
                          ],
                        )
                      : Text(l10n.generateLearningPath),
                ),

                if (!_isGenerating)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      l10n.thisWillCreateAnAIPoweredPersonalizedLearningPath,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the advanced options section
  Widget _buildAdvancedOptions() {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        height: _isAdvancedOptionsVisible ? null : 0,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            // Learning goals
            TextFormField(
              controller: _learningGoalsController,
              decoration: InputDecoration(
                labelText: l10n.learningGoalsOptional,
                hintText: l10n.learningGoalsHint,
                prefixIcon:
                    Icon(PhosphorIcons.target(PhosphorIconsStyle.regular)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
              ),
              enabled: !_isGenerating,
              minLines: 1,
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Learning style
            DropdownButtonFormField<String>(
              value: _learningStyle,
              decoration: InputDecoration(
                labelText: l10n.learningStyleOptional,
                prefixIcon:
                    Icon(PhosphorIcons.brain(PhosphorIconsStyle.regular)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
              ),
              items: _learningStyles
                  .map((style) => DropdownMenuItem(
                        value: style,
                        child: Text(
                          style == 'balanced'
                              ? l10n.balanced
                              : style == 'visual'
                                  ? l10n.visual
                                  : style == 'practical'
                                      ? l10n.practical
                                      : l10n.theoretical,
                        ),
                      ))
                  .toList(),
              onChanged: _isGenerating
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _learningStyle = value;
                        });
                      }
                    },
            ),

            // Commented out - not currently used but kept for future use
            // const SizedBox(height: 16),
            //
            // // Time commitment
            // TextFormField(
            //   controller: _timeCommitmentController,
            //   decoration: InputDecoration(
            //     labelText: 'Time Commitment (Optional)',
            //     hintText: 'e.g. 2 hours daily, 8 hours per week',
            //     prefixIcon:
            //         Icon(PhosphorIcons.clock(PhosphorIconsStyle.regular)),
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(8),
            //     ),
            //     filled: true,
            //   ),
            //   enabled: !_isGenerating,
            //   textInputAction: TextInputAction.next,
            // ),
            //
            // const SizedBox(height: 16),
            //
            // // Focus areas
            // TextFormField(
            //   controller: _focusAreasController,
            //   decoration: InputDecoration(
            //     labelText: 'Focus Areas (Optional)',
            //     hintText:
            //         'Enter specific areas to focus on, separated by commas',
            //     prefixIcon: Icon(
            //         PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular)),
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(8),
            //     ),
            //     filled: true,
            //   ),
            //   enabled: !_isGenerating,
            //   textInputAction: TextInputAction.next,
            // ),
            //
            // const SizedBox(height: 16),
            //
            // // Suggested tags
            // TextFormField(
            //   controller: _suggestedTagsController,
            //   decoration: InputDecoration(
            //     labelText: 'Suggested Tags (Optional)',
            //     hintText:
            //         'Enter tags separated by commas for better organization',
            //     prefixIcon: Icon(PhosphorIcons.tag(PhosphorIconsStyle.regular)),
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(8),
            //     ),
            //     filled: true,
            //     helperText:
            //         'These tags will be used to categorize and filter your learning path',
            //   ),
            //   enabled: !_isGenerating,
            //   textInputAction: TextInputAction.done,
            // ),
          ],
        ),
      ),
    );
  }

  /// Map locale to language name for AI generation
  String? _getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'vi':
        return 'Vietnamese';
      case 'en':
        return 'English';
      default:
        return 'English'; // Default to English
    }
  }
}
