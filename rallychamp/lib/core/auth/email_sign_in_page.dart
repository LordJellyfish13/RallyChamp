import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_repository.dart';
import 'email_password_form.dart';
import 'login_cubit.dart';
import 'login_state.dart';

/// The email/password screen reached by tapping "Sign in with email" on
/// [WelcomePage]. Kept as its own pushed page (rather than inlined on the
/// welcome screen) so the background photo and the three big choices stay
/// uncluttered until someone actually picks that path.
class EmailSignInPage extends StatelessWidget {
  const EmailSignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(AuthRepository()),
      child: const _EmailSignInView(),
    );
  }
}

class _EmailSignInView extends StatelessWidget {
  const _EmailSignInView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            Navigator.of(context).pop(true);
          } else if (state is LoginFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: EmailPasswordSignInForm(),
        ),
      ),
    );
  }
}
