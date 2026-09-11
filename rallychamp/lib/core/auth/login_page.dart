import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_repository.dart';
import 'email_password_form.dart';
import 'login_cubit.dart';
import 'login_state.dart';

/// The mid-app forced sign-in gate — pushed by `ensureSignedIn` when a
/// specific action (creating a rally, applying to one) needs an account.
/// Always pushed as a route, so it pops `true` on success and the caller
/// `await`s the result. The startup experience with a background image
/// and a "browse as guest" option lives in `WelcomePage` instead — this
/// page stays a plain, fast sign-in screen for that mid-app interrupt.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(AuthRepository()),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            Navigator.of(context).pop(true);
          } else if (state is LoginFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          final submitting = state is LoginSubmitting;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Sign in to create or manage rallies, and to apply as a '
                'marshal, judge, or team.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: submitting
                    ? null
                    : () => context.read<LoginCubit>().signInWithGoogle(),
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('or'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              const EmailPasswordSignInForm(),
            ],
          );
        },
      ),
    );
  }
}
