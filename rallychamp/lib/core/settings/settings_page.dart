import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../auth/login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StreamBuilder<User?>(
        stream: authRepository.authStateChanges,
        initialData: authRepository.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user != null ? 'Signed in' : 'Browsing as a guest',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ??
                            'Sign in to create rallies or apply to one.',
                      ),
                      const SizedBox(height: 16),
                      if (user != null)
                        OutlinedButton(
                          onPressed: () => authRepository.signOut(),
                          child: const Text('Sign out'),
                        )
                      else
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                          child: const Text('Sign in'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
