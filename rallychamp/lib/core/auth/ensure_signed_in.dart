import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'login_page.dart';

/// Ensures someone is signed in before proceeding — pushes [LoginPage] if
/// not, and returns whether the caller can now proceed. Used to gate
/// specific actions (creating a rally, applying to one) rather than the
/// whole app, since guest browsing stays login-free — see dev_notes.md §3.
Future<bool> ensureSignedIn(BuildContext context) async {
  if (AuthRepository().currentUser != null) return true;
  final result = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const LoginPage()));
  return result == true;
}
