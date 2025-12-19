import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Failed: ${e.toString()}"),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... _showForgotPasswordDialog logic remains same, just update UI styling inside it if needed ...
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your admin email to receive a reset link.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              decoration: InputDecoration(
                labelText: "Email Address",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (resetEmailController.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(authServiceProvider).sendPasswordResetEmail(resetEmailController.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset link sent!")));
                }
              } catch (e) {
                // handle error
              }
            },
            child: const Text("Send Link"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Clean background color based on theme
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. LOGO / BRANDING
              Icon(
                  Icons.storefront_rounded,
                  size: 80,
                  color: Theme.of(context).primaryColor
              ),
              const SizedBox(height: 16),
              Text(
                "Vision Mart",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                "Management System",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // 2. FORM FIELDS
              TextField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Admin Email',
                  hintText: 'user@example.com',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade300),
                  ),
                ),
                obscureText: _isObscure,
              ),

              // 3. ACTIONS
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text("Forgot Password?"),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      height: 24, width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                  )
                      : const Text(
                    'SIGN IN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}