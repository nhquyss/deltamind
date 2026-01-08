import 'package:deltamind/core/constants/app_constants.dart';
import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/core/theme/app_theme.dart';
import 'package:deltamind/features/quiz/quiz_controller.dart';
import 'package:deltamind/services/gemini_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Page for creating a new quiz
class CreateQuizPage extends ConsumerStatefulWidget {
  /// Default constructor
  const CreateQuizPage({super.key});

  @override
  ConsumerState<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends ConsumerState<CreateQuizPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedQuizType = AppConstants.quizTypes.first;
  String _selectedDifficulty = AppConstants.quizDifficulties.first;
  int _questionCount = 5;
  bool _isLoading = false;
  String? _errorMessage;
  String? _filePath;
  String? _fileName;
  Uint8List? _fileBytes;
  // Define max file size constant if not in AppConstants
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true, // Ensures bytes are available for web platform
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        // Check file size
        if (file.size > maxFileSize) {
          setState(() {
            _errorMessage = l10n.fileIsTooLarge;
          });
          return;
        }

        // Validate if we have bytes for web platform
        if (kIsWeb && file.bytes == null) {
          setState(() {
            _errorMessage = l10n.errorCannotAccessFileData;
          });
          return;
        }

        final String fileExtension = file.name.split('.').last.toLowerCase();
        if (![
          'txt',
          'pdf',
          'doc',
          'docx',
          'jpg',
          'jpeg',
          'png',
        ].contains(fileExtension)) {
          setState(() {
            _errorMessage = l10n.unsupportedFileFormat;
          });
          return;
        }

        // Set a suggested title based on the file name
        final fileNameWithoutExtension = file.name.split('.').first;
        if (_titleController.text.isEmpty) {
          _titleController.text = fileNameWithoutExtension.replaceAll('_', ' ');
        }

        setState(() {
          _fileName = file.name;
          _fileBytes = file.bytes; // This works on all platforms including web
          // Only set path if not on web platform
          if (!kIsWeb) {
            _filePath = file.path;
          }
          _errorMessage = null;
        });

        // Update the UI to show the file is ready for processing
        setState(() {
          _contentController.text = '${l10n.uploadFile}: $_fileName\n\n'
              '${_getFileTypeDescription(fileExtension)} ${l10n.readyForProcessing}.\n\n'
              '${l10n.clickGenerateQuizToCreate}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = l10n.errorPickingFile(e.toString());
      });
    }
  }

  String _getFileTypeDescription(String extension) {
    switch (extension) {
      case 'pdf':
        return 'PDF document';
      case 'doc':
      case 'docx':
        return 'Word document';
      case 'txt':
        return 'Text file';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'Image file';
      default:
        return 'File';
    }
  }

  Future<void> _generateQuiz() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    if (_contentController.text.trim().isEmpty && _fileBytes == null) {
      setState(() {
        _errorMessage = l10n.pleaseEnterContentOrUploadFile;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Process file if available
      if (_fileBytes != null && _fileName != null) {
        final String fileExtension = _fileName!.split('.').last.toLowerCase();

        final l10n = AppLocalizations.of(context)!;
        // Update loading state with file processing info
        setState(() {
          _contentController.text =
              l10n.processingFile(fileExtension.toUpperCase());
        });

        if (fileExtension == 'pdf') {
          try {
            // Load PDF document from bytes (works on all platforms)
            final PdfDocument document = PdfDocument(inputBytes: _fileBytes);
            final PdfTextExtractor extractor = PdfTextExtractor(document);

            // Extract text from all pages
            final buffer = StringBuffer();
            final l10n = AppLocalizations.of(context)!;
            for (int i = 1; i <= document.pages.count; i++) {
              setState(() {
                _contentController.text =
                    l10n.processingPdfPage(i, document.pages.count);
              });

              String text = extractor.extractText(
                startPageIndex: i - 1,
                endPageIndex: i - 1,
              );
              buffer.write(text);
              buffer.write('\n\n');
            }

            // Update text content
            setState(() {
              _contentController.text = buffer.toString();
            });

            // Dispose the document
            document.dispose();
          } catch (e) {
            final l10n = AppLocalizations.of(context)!;
            setState(() {
              _errorMessage = l10n.errorProcessingPdf(e.toString());
              _isLoading = false;
            });
            return;
          }
        } else if (fileExtension == 'txt') {
          try {
            // Use file bytes for consistent behavior across platforms
            final fileContent = utf8.decode(_fileBytes!);
            setState(() {
              _contentController.text = fileContent;
            });
          } catch (e) {
            final l10n = AppLocalizations.of(context)!;
            setState(() {
              _errorMessage = l10n.errorReadingTextFile(e.toString());
              _isLoading = false;
            });
            return;
          }
        } else if ([
          'doc',
          'docx',
          'jpg',
          'jpeg',
          'png',
        ].contains(fileExtension)) {
          // For complex file types like documents and images, use the specialized method
          // Process directly with Gemini

          // Use the title from the title field
          final title = _titleController.text.trim();

          // Get current locale and map to language name
          final locale = Localizations.localeOf(context);
          final language = _getLanguageName(locale);

          // Use the Riverpod controller to generate the quiz directly from file
          final quizController = ref.read(quizControllerProvider.notifier);

          final quiz = await quizController.generateQuizFromFile(
            title: title,
            description: 'Generated quiz based on ${_fileName!}',
            quizType: _selectedQuizType,
            difficulty: _selectedDifficulty,
            fileBytes: _fileBytes!,
            fileName: _fileName!,
            questionCount: _questionCount,
            language: language,
          );

          if (!mounted) return;

          if (quiz != null) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Quiz generated successfully!'),
                backgroundColor: AppTheme.successColor,
              ),
            );

            // Navigate to the quiz details page
            context.go('/quiz/${quiz.id}');
            return; // Exit early as we've already handled this case
          } else {
            final l10n = AppLocalizations.of(context)!;
            throw Exception(l10n.failedToGenerateQuizFromFile);
          }
        } else {
          setState(() {
            _errorMessage = 'Unsupported file type: $fileExtension';
            _isLoading = false;
          });
          return;
        }
      }

      // If we get here, we're processing text content
      // Use the title from the title field
      final title = _titleController.text.trim();

      final l10n = AppLocalizations.of(context)!;
      // Update UI to show we're generating the quiz
      setState(() {
        _contentController.text =
            '${_contentController.text}\n\n${l10n.generatingQuizQuestions}';
      });

      // Get current locale and map to language name
      final locale = Localizations.localeOf(context);
      final language = _getLanguageName(locale);

      // Use the Riverpod controller to generate the quiz
      final quizController = ref.read(quizControllerProvider.notifier);

      final quiz = await quizController.generateQuiz(
        title: title,
        description: 'Generated quiz based on provided content',
        quizType: _selectedQuizType,
        difficulty: _selectedDifficulty,
        content: _contentController.text,
        questionCount: _questionCount,
        language: language,
      );

      if (!mounted) return;

      if (quiz != null) {
        // Show success message
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.quizGeneratedSuccessfully),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Navigate to the quiz details page
        context.go('/quiz/${quiz.id}');
      } else {
        final l10n = AppLocalizations.of(context)!;
        throw Exception(l10n.failedToGenerateQuiz);
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.errorGeneratingQuiz(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createQuizTitle),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.sparkle(),
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.aiQuizGenerator,
                          style: AppTheme.headingMedium.copyWith(
                            color: AppColors.primary,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.createQuizDescription,
                      style: AppTheme.bodyText.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quiz title field
              Text(
                l10n.quizTitle,
                style: AppTheme.subtitle.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.pleaseEnterQuizTitle;
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: l10n.enterQuizTitle,
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(
                    PhosphorIcons.textT(),
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Settings card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.gearSix(),
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.quizSettings,
                          style: AppTheme.subtitle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quiz type selection
                    Text(
                      l10n.quizType,
                      style: AppTheme.smallText.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedQuizType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.primary.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: AppConstants.quizTypes.map((type) {
                        String displayType = type;
                        if (type == 'Multiple Choice') {
                          displayType = l10n.quizTypeMultipleChoice;
                        } else if (type == 'True/False') {
                          displayType = l10n.quizTypeTrueFalse;
                        } else if (type == 'Fill in the Blank') {
                          displayType = l10n.quizTypeFillInTheBlank;
                        }
                        return DropdownMenuItem(
                          value: type,
                          child: Text(displayType),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedQuizType = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),

                    // Difficulty selection
                    Text(
                      l10n.difficulty,
                      style: AppTheme.smallText.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDifficulty,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.primary.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: AppConstants.quizDifficulties.map((difficulty) {
                        String displayDifficulty = difficulty;
                        if (difficulty == 'Easy') {
                          displayDifficulty = l10n.quizDifficultyEasy;
                        } else if (difficulty == 'Medium') {
                          displayDifficulty = l10n.quizDifficultyMedium;
                        } else if (difficulty == 'Hard') {
                          displayDifficulty = l10n.quizDifficultyHard;
                        } else if (difficulty == 'Expert') {
                          displayDifficulty = l10n.quizDifficultyExpert;
                        }
                        return DropdownMenuItem(
                          value: difficulty,
                          child: Text(displayDifficulty),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedDifficulty = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),

                    // Question count
                    Text(
                      l10n.numberOfQuestions(_questionCount),
                      style: AppTheme.smallText.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withOpacity(0.1),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                      ),
                      child: Slider(
                        value: _questionCount.toDouble(),
                        min: 3,
                        max: 10,
                        divisions: 7,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _questionCount = value.round();
                                });
                              },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Content section
              Text(
                l10n.studyMaterial,
                style: AppTheme.subtitle.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.studyMaterialHint,
                style: AppTheme.smallText.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Upload button and file indicator
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.fileArrowUp(),
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.fileUpload,
                          style: AppTheme.subtitle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickFile,
                      icon: Icon(
                        PhosphorIcons.upload(),
                        color: AppColors.primary,
                      ),
                      label: Text(
                        _fileName != null ? l10n.changeFile : l10n.uploadFile,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (_fileName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIcons.file(),
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fileName!,
                                style: AppTheme.smallText,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                PhosphorIcons.x(),
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _filePath = null;
                                  _fileName = null;
                                  _fileBytes = null;
                                });
                              },
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Text content
              TextField(
                controller: _contentController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: l10n.pasteYourNotes,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.warning(), color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Generate button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _generateQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(l10n.generatingQuiz),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(l10n.generateQuiz),
                            const SizedBox(width: 8),
                            Icon(PhosphorIcons.sparkle()),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
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
