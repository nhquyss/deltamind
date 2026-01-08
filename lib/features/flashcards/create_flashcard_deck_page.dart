import 'dart:io';
import 'dart:typed_data';
import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/models/flashcard.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:deltamind/services/flashcard_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// CreateFlashcardDeckPage allows creating flashcards from files
class CreateFlashcardDeckPage extends StatefulWidget {
  /// Creates a CreateFlashcardDeckPage
  const CreateFlashcardDeckPage({Key? key}) : super(key: key);

  @override
  State<CreateFlashcardDeckPage> createState() =>
      _CreateFlashcardDeckPageState();
}

class _CreateFlashcardDeckPageState extends State<CreateFlashcardDeckPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedFile;
  Uint8List? _webFileBytes;
  String? _selectedFileName;
  String? _selectedFileType;
  int _cardCount = 10;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        withData: true, // Important for web - get file bytes
      );

      if (result != null) {
        final fileName = result.files.single.name;
        final fileExt = fileName.split('.').last.toLowerCase();

        setState(() {
          _selectedFileName = fileName;
          _selectedFileType = fileExt;

          // Handle file differently based on platform
          if (kIsWeb) {
            // For web, store bytes
            _webFileBytes = result.files.single.bytes;
            _selectedFile = null;
          } else {
            // For mobile platforms, create File object from path
            final path = result.files.single.path;
            if (path != null) {
              _selectedFile = File(path);
              _webFileBytes = null;
            }
          }

          // Default title from filename without extension
          if (_titleController.text.isEmpty) {
            _titleController.text = fileName.split('.').first;
          }
        });
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.errorPickingFileFlashcards(e.toString());
      });
    }
  }

  Future<void> _createDeck() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    if (_selectedFile == null && _webFileBytes == null) {
      setState(() {
        _errorMessage = l10n.pleaseSelectFileToGenerateFlashcards;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Get current locale and map to language name
      final locale = Localizations.localeOf(context);
      final language = _getLanguageName(locale);

      final deck = await FlashcardService.createFlashcardsFromFile(
        file: _selectedFile,
        fileBytes: _webFileBytes,
        fileName: _selectedFileName!,
        fileType: _selectedFileType!,
        title: _titleController.text,
        description: _descriptionController.text,
        cardCount: _cardCount,
        language: language,
      );

      final l10n = AppLocalizations.of(context)!;
      if (mounted) {
        // Show success and navigate to the deck detail page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.createdFlashcards(deck.cardCount)),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/flashcards/${deck.id}');
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isProcessing = false;
        _errorMessage = l10n.errorCreatingFlashcards(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createFlashcardDeck),
      ),
      body: _isProcessing
          ? _buildLoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
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
                    _buildFileSelector(),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.deckTitle,
                        hintText: l10n.enterTitleForFlashcardDeck,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.pleaseEnterTitle;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.descriptionOptional,
                        hintText: l10n.addDescriptionForFlashcards,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    _buildCardCountSelector(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            (_selectedFile != null || _webFileBytes != null)
                                ? _createDeck
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          l10n.generateFlashcards,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
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

  Widget _buildLoadingView() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            l10n.generatingFlashcards,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.usingAIToCreateFlashcards(
                _cardCount, _selectedFileName ?? 'your file'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.thisMayTakeAMinuteOrTwo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelector() {
    final l10n = AppLocalizations.of(context)!;
    final bool hasSelectedFile = _selectedFile != null || _webFileBytes != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          Text(
            l10n.uploadFileToGenerateFlashcards,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.selectPdfTxtOrDocFile,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (!hasSelectedFile) ...[
            Icon(
              PhosphorIconsFill.fileArrowUp,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_upload),
              label: Text(l10n.selectFile),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  _fileTypeIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFileName!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.fileType(_selectedFileType?.toUpperCase() ?? ''),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _webFileBytes = null;
                        _selectedFileName = null;
                        _selectedFileType = null;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.grey),
                    tooltip: l10n.removeFile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_upload, size: 16),
              label: Text(l10n.chooseDifferentFile),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fileTypeIcon() {
    if (_selectedFileType == null) {
      return Icon(PhosphorIconsRegular.file, color: Colors.grey[600]);
    }

    switch (_selectedFileType) {
      case 'pdf':
        return Icon(PhosphorIconsRegular.filePdf, color: Colors.red[600]);
      case 'doc':
      case 'docx':
        return Icon(PhosphorIconsRegular.fileDoc, color: Colors.blue[600]);
      case 'txt':
        return Icon(PhosphorIconsRegular.fileTxt, color: Colors.grey[600]);
      default:
        return Icon(PhosphorIconsRegular.file, color: Colors.grey[600]);
    }
  }

  Widget _buildCardCountSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.numberOfFlashcardsToGenerate(_cardCount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _cardCount.toDouble(),
          min: 5,
          max: 30,
          divisions: 25,
          label: _cardCount.toString(),
          onChanged: (value) {
            setState(() {
              _cardCount = value.round();
            });
          },
        ),
        Text(
          l10n.tipStartWithFewerCards,
          style: const TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
