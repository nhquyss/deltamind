import 'package:deltamind/core/routing/app_router.dart';
import 'package:deltamind/core/theme/app_theme.dart';
import 'package:deltamind/services/supabase_service.dart';
import 'package:deltamind/widgets/language_switcher_button.dart';
import 'package:deltamind/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reset password page (used for both forgot password and change password)
class ResetPasswordPage extends StatefulWidget {
  /// Whether this is a change password flow (requires old password)
  final bool isChangePassword;

  /// Default constructor
  const ResetPasswordPage({
    super.key,
    this.isChangePassword = false,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isChangePassword) {
        // For change password, verify old password first
        final user = SupabaseService.currentUser;
        if (user?.email == null) {
          throw Exception(AppLocalizations.of(context)!.userNotFound);
        }

        // Try to sign in with old password to verify it
        try {
          await SupabaseService.signInWithEmailAndPassword(
            user!.email!,
            _oldPasswordController.text,
          );
        } catch (e) {
          throw Exception(
              AppLocalizations.of(context)!.currentPasswordIncorrect);
        }

        // Update to new password
        await SupabaseService.updatePassword(_newPasswordController.text);
      } else {
        // For forgot password, just update the password
        // The user is already authenticated via the reset token from email
        final user = SupabaseService.currentUser;
        if (user == null) {
          throw Exception(
            AppLocalizations.of(context)!.clickEmailLinkToReset,
          );
        }
        await SupabaseService.resetPassword(
          newPassword: _newPasswordController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.passwordUpdatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back or to login
        if (widget.isChangePassword) {
          context.pop();
        } else {
          context.go(AppRoutes.login);
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isChangePassword ? l10n.changePassword : l10n.resetPassword,
        ),
        actions: const [
          LanguageSwitcherButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                Icon(
                  widget.isChangePassword
                      ? Icons.lock_outline
                      : Icons.lock_reset,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  widget.isChangePassword
                      ? l10n.changeYourPassword
                      : l10n.setNewPassword,
                  style: AppTheme.headingLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  widget.isChangePassword
                      ? l10n.changePasswordDescription
                      : l10n.setNewPasswordDescription,
                  style: AppTheme.bodyText.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Old password field (only for change password)
                if (widget.isChangePassword) ...[
                  TextFormField(
                    controller: _oldPasswordController,
                    decoration: InputDecoration(
                      labelText: l10n.currentPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureOldPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureOldPassword = !_obscureOldPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureOldPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.pleaseEnterCurrentPassword;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // New password field
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: l10n.newPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureNewPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pleaseEnterANewPassword;
                    }
                    if (value.length < 6) {
                      return l10n.passwordTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: l10n.confirmNewPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pleaseConfirmNewPassword;
                    }
                    if (value != _newPasswordController.text) {
                      return l10n.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: AppTheme.errorColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),

                // Submit button
                LoadingButton(
                  onPressed: _resetPassword,
                  isLoading: _isLoading,
                  child: Text(
                    widget.isChangePassword
                        ? l10n.changePassword
                        : l10n.resetPassword,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
