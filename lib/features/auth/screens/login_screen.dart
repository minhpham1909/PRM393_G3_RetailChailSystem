import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/auth_service.dart';

/// Login UI theo thiết kế Stitch (Prism Retail)
/// - Email / Password
/// - Remember device (UI only)
/// - Link forgot password
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isSubmitting = false;
  String? _errorText;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      // Điều hướng về AuthGate để nó check role và redirect tới manager/admin
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Email hoặc mật khẩu không đúng.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Background blur blobs giống Stitch
          Positioned(
            bottom: -80,
            left: -80,
            child: _BlurBlob(
              color: colorScheme.primary.withOpacity(0.08),
              size: 320,
            ),
          ),
          Positioned(
            bottom: -40,
            right: -60,
            child: _BlurBlob(
              color: colorScheme.secondary.withOpacity(0.08),
              size: 260,
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      _BrandHeader(colorScheme: colorScheme),
                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_errorText != null) ...[
                                _ErrorBanner(message: _errorText!),
                                const SizedBox(height: 12),
                              ],

                              _LabeledTextField(
                                label: 'Email Address',
                                hintText: 'name@prismretail.com',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.mail_outline,
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty)
                                    return 'Vui lòng nhập email.';
                                  if (!value.contains('@'))
                                    return 'Email không hợp lệ.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              _PasswordField(
                                label: 'Password',
                                controller: _passwordController,
                                onForgot: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.forgotPassword,
                                  );
                                },
                                validator: (v) {
                                  if ((v ?? '').isEmpty)
                                    return 'Vui lòng nhập mật khẩu.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Row(
                              //   children: [
                              //     Checkbox(
                              //       value: _rememberMe,
                              //       onChanged: (v) => setState(
                              //         () => _rememberMe = v ?? false,
                              //       ),
                              //     ),
                              //     const SizedBox(width: 6),
                              //     Expanded(
                              //       child: Text(
                              //         'Remember this device',
                              //         style: Theme.of(context)
                              //             .textTheme
                              //             .bodySmall
                              //             ?.copyWith(
                              //               color: colorScheme.onSurfaceVariant,
                              //             ),
                              //       ),
                              //     ),
                              //   ],
                              // ),
                              // const SizedBox(height: 8),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: const StadiumBorder(),
                                    elevation: 2,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'LOGIN',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                letterSpacing: 2,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 18),
                              Divider(
                                color: colorScheme.surfaceContainerHighest,
                              ),
                              const SizedBox(height: 18),

                              Text(
                                'AUTHORIZED PERSONNEL ONLY',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PillStatus(
                                    dotColor: colorScheme.secondary,
                                    text: 'System Active',
                                    background: colorScheme.secondaryContainer
                                        .withOpacity(0.25),
                                    textColor: colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  _PillIconStatus(
                                    icon: Icons.security,
                                    text: 'Encrypted',
                                    background: colorScheme.primaryContainer
                                        .withOpacity(0.18),
                                    iconColor: colorScheme.primary,
                                    textColor: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary.withOpacity(
                                    0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      Text(
                        '© 2024 Prism Retail Management Systems\nEnterprise Version 4.2.0-Editorial',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                          letterSpacing: 1.4,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.primary, colorScheme.primaryContainer],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.diamond, color: colorScheme.onPrimary, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'Prism Retail',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'The Digital Curator for Modern Commerce',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: UnderlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.onForgot,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onForgot;
  final String? Function(String?)? validator;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onForgot,
                child: Text(
                  'Forgot Password?',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: UnderlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillStatus extends StatelessWidget {
  const _PillStatus({
    required this.dotColor,
    required this.text,
    required this.background,
    required this.textColor,
  });

  final Color dotColor;
  final String text;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 10,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillIconStatus extends StatelessWidget {
  const _PillIconStatus({
    required this.icon,
    required this.text,
    required this.background,
    required this.iconColor,
    required this.textColor,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 10,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
