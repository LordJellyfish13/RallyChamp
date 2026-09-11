import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_cubit.dart';
import 'login_state.dart';

/// The email/password fields + Sign In/Sign Up toggle, shared between
/// [LoginPage] (the mid-app forced sign-in gate) and `EmailSignInPage`
/// (reached from the startup `WelcomePage`). Reads its [LoginCubit] from
/// an ancestor `BlocProvider` — the enclosing page owns success/failure
/// handling (pop vs. rely on the auth-state stream), this widget only
/// owns the form fields.
class EmailPasswordSignInForm extends StatefulWidget {
  const EmailPasswordSignInForm({super.key});

  @override
  State<EmailPasswordSignInForm> createState() =>
      _EmailPasswordSignInFormState();
}

class _EmailPasswordSignInFormState extends State<EmailPasswordSignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LoginCubit>().submitEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      isSignUp: _isSignUp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginCubit, LoginState>(
      builder: (context, state) {
        final submitting = state is LoginSubmitting;
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: submitting ? null : _submit,
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isSignUp ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: submitting
                    ? null
                    : () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign in'
                      : "Don't have an account? Sign up",
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
