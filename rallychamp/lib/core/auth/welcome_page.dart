import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/app_colors.dart';
import 'auth_repository.dart';
import 'email_sign_in_page.dart';
import 'login_cubit.dart';
import 'login_state.dart';

/// The very first screen most people see: a full-bleed hero image behind
/// three choices (Google, email, or guest). This is what `AuthGate` shows
/// on a fresh install, before anyone has signed in or picked "guest" — see
/// dev_notes.md §5 "A real login page" for how it fits with `LoginPage`
/// (the plain mid-app sign-in gate) and `ensureSignedIn`.
///
/// The background is a themed gradient placeholder for now — drop a real
/// rally photo in as `assets/images/welcome_background.jpg` (declared under
/// `flutter: assets:` in pubspec.yaml) and swap the `DecoratedBox` below for
/// `Image.asset(...)` when one is ready.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onContinueAsGuest});

  final VoidCallback onContinueAsGuest;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(AuthRepository()),
      child: _WelcomeView(onContinueAsGuest: onContinueAsGuest),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.onContinueAsGuest});

  final VoidCallback onContinueAsGuest;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginCubit, LoginState>(
      listener: (context, state) {
        // LoginSuccess needs no handling here — AuthGate's own auth-state
        // stream swaps this whole page out for MainScreen once Firebase
        // confirms the sign-in.
        if (state is LoginFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.charcoal, Color(0xFF3A1108)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'RALLYCHAMP',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(color: Colors.white, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Live stages, checkpoints, and results — even deep in '
                    'the forest.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<LoginCubit, LoginState>(
                    builder: (context, state) {
                      final submitting = state is LoginSubmitting;
                      return FilledButton.icon(
                        onPressed: submitting
                            ? null
                            : () =>
                                  context.read<LoginCubit>().signInWithGoogle(),
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google'),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EmailSignInPage(),
                      ),
                    ),
                    child: const Text('Sign in with email'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: onContinueAsGuest,
                    child: const Text('Browse as guest'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
