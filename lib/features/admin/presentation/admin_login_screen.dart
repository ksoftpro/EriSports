import 'package:eri_sports/features/admin/data/admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const adminLoginUsernameFieldKey = Key('adminLoginUsernameField');
const adminLoginPasswordFieldKey = Key('adminLoginPasswordField');
const adminLoginConfirmPasswordFieldKey = Key('adminLoginConfirmPasswordField');
const adminLoginDisplayNameFieldKey = Key('adminLoginDisplayNameField');
const adminLoginSubmitButtonKey = Key('adminLoginSubmitButton');

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _persistSession = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authService = ref.read(adminAuthServiceProvider);
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result =
        authService.requiresSetup
            ? await authService.createInitialAdmin(
              username: _usernameController.text,
              displayName: _displayNameController.text,
              password: _passwordController.text,
              confirmPassword: _confirmPasswordController.text,
              persistSession: _persistSession,
            )
            : await authService.login(
              username: _usernameController.text,
              password: _passwordController.text,
              persistSession: _persistSession,
            );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = result.success ? null : result.message;
    });

    if (result.success && mounted) {
      context.go('/secure-content');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(adminAuthServiceProvider);
    final requiresSetup = authService.requiresSetup;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.surface,
              scheme.surfaceContainerHighest,
              scheme.primary.withValues(alpha: 0.14),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_rounded,
                            color: scheme.primary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          requiresSetup
                              ? 'Initialize Admin Access'
                              : 'Admin Secure Content Console',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          requiresSetup
                              ? 'Create the primary administrator before any secure-content tools become available.'
                              : 'Authenticate before opening secure content operations, audit history, and account controls.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        if (requiresSetup) ...[
                          TextField(
                            key: adminLoginDisplayNameFieldKey,
                            controller: _displayNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Display name',
                              hintText: 'Operations Lead',
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          key: adminLoginUsernameFieldKey,
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            hintText: 'admin',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: adminLoginPasswordFieldKey,
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction:
                              requiresSetup
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                          onSubmitted: (_) {
                            if (!requiresSetup) {
                              _submit();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                        ),
                        if (requiresSetup) ...[
                          const SizedBox(height: 14),
                          TextField(
                            key: adminLoginConfirmPasswordFieldKey,
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _persistSession,
                          onChanged: (value) {
                            setState(() {
                              _persistSession = value ?? false;
                            });
                          },
                          title: const Text('Keep this session on this device'),
                          subtitle: const Text(
                            'Leave off on shared machines to require login again after restart.',
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.error),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          key: adminLoginSubmitButtonKey,
                          onPressed: _isSubmitting ? null : _submit,
                          icon: Icon(
                            requiresSetup
                                ? Icons.lock_person_rounded
                                : Icons.login_rounded,
                          ),
                          label: Text(
                            _isSubmitting
                                ? (requiresSetup
                                    ? 'Creating admin...'
                                    : 'Signing in...')
                                : (requiresSetup
                                    ? 'Create admin and continue'
                                    : 'Sign in to dashboard'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}