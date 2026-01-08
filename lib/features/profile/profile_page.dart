import 'dart:io';
import 'dart:typed_data';

import 'package:deltamind/core/locale/locale_controller.dart';
import 'package:deltamind/core/routing/app_router.dart';
import 'package:deltamind/core/theme/app_colors.dart';
import 'package:deltamind/features/auth/auth_controller.dart';
import 'package:deltamind/services/supabase_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Profile page
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isLoading = false;
  bool _isUploadingImage = false;
  Map<String, dynamic>? _profileData;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  /// Load user profile data
  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        final profile = await SupabaseService.getUserProfile(user.id);
        setState(() {
          _profileData = profile;
          _usernameController.text = profile?['username'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Show options for picking profile picture
  Future<void> _showImageSourceOptions() async {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.of(context).pop();
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(l10n.takeAPhoto),
              onTap: () {
                Navigator.of(context).pop();
                _pickImageFromCamera();
              },
            ),
            if (kIsWeb || !Platform.isIOS && !Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: Text(l10n.uploadFile),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFileFromSystem();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      Uint8List? imageBytes;
      String? fileName;

      // Try using ImagePicker first
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (image != null) {
          imageBytes = await image.readAsBytes();
          fileName = image.name;
        }
      } catch (e) {
        debugPrint('Error with ImagePicker, falling back to FilePicker: $e');
        // Fall back to FilePicker if ImagePicker fails
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.single.bytes != null) {
          imageBytes = result.files.single.bytes!;
          fileName = result.files.single.name;
        }
      }

      // If we have an image, upload it
      if (imageBytes != null && fileName != null) {
        await _uploadProfilePicture(imageBytes, fileName);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showErrorSnackBar(AppLocalizations.of(context)!.errorPickingImage);
    }
  }

  /// Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      Uint8List? imageBytes;
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Try using ImagePicker for camera
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (photo != null) {
          imageBytes = await photo.readAsBytes();
          fileName = photo.name;
        }
      } catch (e) {
        debugPrint('Error with camera: $e');
        // Alert user that camera is not available
        _showErrorSnackBar(
          AppLocalizations.of(context)!.cameraNotAvailable,
        );
        return;
      }

      // If we have an image, upload it
      if (imageBytes != null) {
        await _uploadProfilePicture(imageBytes, fileName);
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      _showErrorSnackBar(AppLocalizations.of(context)!.errorTakingPhoto);
    }
  }

  /// Pick file from system (for web or desktop)
  Future<void> _pickFileFromSystem() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif'],
      );

      if (result != null && result.files.single.bytes != null) {
        await _uploadProfilePicture(
          result.files.single.bytes!,
          result.files.single.name,
        );
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      _showErrorSnackBar(
          AppLocalizations.of(context)!.errorPickingFile('Please try again'));
    }
  }

  /// Upload profile picture to Supabase
  Future<void> _uploadProfilePicture(Uint8List bytes, String fileName) async {
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        // Get file extension and determine content type
        final fileExt = fileName.split('.').last.toLowerCase();
        String contentType = 'image/jpeg';

        if (fileExt == 'png') {
          contentType = 'image/png';
        } else if (fileExt == 'gif') {
          contentType = 'image/gif';
        }

        // Delete old profile picture if exists
        final oldAvatarUrl = _profileData?['avatar_url'];
        if (oldAvatarUrl != null) {
          await SupabaseService.deleteOldProfilePicture(oldAvatarUrl);
        }

        // Upload new profile picture
        final avatarUrl = await SupabaseService.uploadProfilePicture(
          userId: user.id,
          fileBytes: bytes,
          fileName: fileName,
          fileType: contentType,
        );

        if (avatarUrl != null) {
          // Update profile data locally
          setState(() {
            if (_profileData != null) {
              _profileData!['avatar_url'] = avatarUrl;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .profilePictureUpdatedSuccessfully),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          _showErrorSnackBar(
              AppLocalizations.of(context)!.failedToUploadProfilePicture);
        }
      }
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      _showErrorSnackBar(
          AppLocalizations.of(context)!.errorUploadingProfilePicture);
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  /// Update user profile
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        await SupabaseService.updateUserProfile(
          userId: user.id,
          username: _usernameController.text,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.profileUpdated),
            backgroundColor: AppColors.success,
          ),
        );

        await _loadProfile();
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${AppLocalizations.of(context)!.errorUpdatingProfile}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Sign out user
  Future<void> _signOut() async {
    // Set loading state only if still mounted
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Sign out first
      await ref.read(authControllerProvider.notifier).signOut();

      // Wait for a small delay to ensure auth state is updated
      await Future.delayed(const Duration(milliseconds: 100));

      // Then navigate (only if still mounted)
      if (mounted) {
        // Clear navigation history and go to login
        context.go(AppRoutes.login);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.signedOutSuccessfully),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context)!.errorSigningOut}: $e'),
            backgroundColor: AppColors.error,
          ),
        );

        // Even if sign out failed, redirect to login for safety
        context.go(AppRoutes.login);
      }
    } finally {
      // Only update state if the widget is still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsFill.signOut),
            onPressed: _isLoading ? null : _signOut,
            tooltip: l10n.logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header
                  _buildProfileHeader(user),
                  const SizedBox(height: 24),

                  // Profile form
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.profileInformation,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: l10n.username,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.pleaseEnterUsername;
                                }
                                if (value.length < 3) {
                                  return l10n.usernameTooShort;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _updateProfile,
                                child: Text(l10n.save),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Shortcuts section
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.shortcuts,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            title: Text(l10n.achievements),
                            leading: const Icon(
                              PhosphorIconsFill.trophy,
                              color: AppColors.accent,
                            ),
                            onTap: () => context.push(AppRoutes.achievements),
                          ),
                          const Divider(),
                          ListTile(
                            title: Text(l10n.analytics),
                            leading: const Icon(
                              PhosphorIconsFill.chartLine,
                              color: AppColors.primary,
                            ),
                            onTap: () => context.push(AppRoutes.analytics),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account section
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.accountInformation,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            title: Text(l10n.email),
                            subtitle: Text(user?.email ?? l10n.notAvailable),
                            leading: const Icon(
                              Icons.email,
                              color: AppColors.primary,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            title: Text(l10n.userID),
                            subtitle: Text(
                              user?.id ?? l10n.notAvailable,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            leading: const Icon(
                              Icons.perm_identity,
                              color: AppColors.secondary,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            title: Text(l10n.joined),
                            subtitle: Text(
                              user?.createdAt != null
                                  ? _formatDate(
                                      DateTime.parse(user!.createdAt),
                                    )
                                  : l10n.notAvailable,
                            ),
                            leading: const Icon(
                              Icons.calendar_today,
                              color: AppColors.accent,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            title: Text(l10n.changePassword),
                            leading: const Icon(
                              Icons.lock_outline,
                              color: AppColors.primary,
                            ),
                            onTap: () {
                              context.push(AppRoutes.changePassword);
                            },
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                          ),
                          const Divider(),
                          _buildLanguageSelector(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions section
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: const BorderSide(color: AppColors.error, width: 2),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      title: Text(l10n.logout),
                      leading: const Icon(
                        Icons.logout,
                        color: AppColors.error,
                      ),
                      onTap: _isLoading ? null : _signOut,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Build profile header with avatar and name
  Widget _buildProfileHeader(user) {
    final avatarUrl = _profileData?['avatar_url'];

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Avatar
              GestureDetector(
                onTap: _isUploadingImage ? null : _showImageSourceOptions,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.1),
                    border: Border.all(color: Colors.blue, width: 3),
                  ),
                  child: _isUploadingImage
                      ? const CircularProgressIndicator()
                      : (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                avatarUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildInitialsAvatar();
                                },
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                              ),
                            )
                          : _buildInitialsAvatar(),
                ),
              ),

              // Camera icon
              if (!_isUploadingImage)
                GestureDetector(
                  onTap: _showImageSourceOptions,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _profileData?['username'] ??
                user?.email?.split('@').first ??
                AppLocalizations.of(context)!.user,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            user?.email ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Build avatar with user initials
  Widget _buildInitialsAvatar() {
    return Center(
      child: Text(
        _getInitials(),
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// Get user initials for avatar
  String _getInitials() {
    final username = _profileData?['username'] ?? '';
    if (username.isNotEmpty) {
      return username[0].toUpperCase();
    }

    final email = SupabaseService.currentUser?.email ?? '';
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }

    return 'U';
  }

  /// Format date to readable string
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Build language selector
  Widget _buildLanguageSelector() {
    final l10n = AppLocalizations.of(context)!;
    final localeState = ref.watch(localeControllerProvider);
    final currentLocale = localeState.locale;

    return ListTile(
      title: Text(l10n.language),
      subtitle: Text(
        currentLocale.languageCode == 'vi' ? l10n.vietnamese : l10n.english,
      ),
      leading: const Icon(
        Icons.language,
        color: AppColors.primary,
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showLanguageDialog(currentLocale),
    );
  }

  /// Show language selection dialog
  void _showLanguageDialog(Locale currentLocale) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<Locale>(
              title: Text(l10n.english),
              value: const Locale('en', ''),
              groupValue: currentLocale,
              onChanged: (Locale? value) {
                if (value != null) {
                  ref.read(localeControllerProvider.notifier).setLocale(value);
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<Locale>(
              title: Text(l10n.vietnamese),
              value: const Locale('vi', ''),
              groupValue: currentLocale,
              onChanged: (Locale? value) {
                if (value != null) {
                  ref.read(localeControllerProvider.notifier).setLocale(value);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
