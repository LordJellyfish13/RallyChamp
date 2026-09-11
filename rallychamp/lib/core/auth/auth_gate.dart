import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../navigation/main_screen.dart';
import 'auth_repository.dart';
import 'guest_preference.dart';
import 'welcome_page.dart';

/// The app's startup screen: shows [LoginPage] (with a "Continue as guest"
/// option) once per install, then remembers the choice so returning
/// users — signed in or guest — land straight on [MainScreen]. Signing in
/// from elsewhere in the app (via `ensureSignedIn`) is unaffected; this only
/// controls what's shown on launch. See dev_notes.md §5 "A real login page".
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _guestChosen = false;
  late final Future<bool> _initialGuestCheck = GuestPreference.hasChosenGuest();

  void _continueAsGuest() {
    GuestPreference.setChosenGuest();
    setState(() => _guestChosen = true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initialGuestCheck,
      builder: (context, guestSnapshot) {
        if (!guestSnapshot.hasData) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final alreadyGuest = guestSnapshot.data! || _guestChosen;
        return StreamBuilder<User?>(
          stream: AuthRepository().authStateChanges,
          builder: (context, authSnapshot) {
            if (authSnapshot.data != null || alreadyGuest) {
              return const MainScreen();
            }
            return WelcomePage(onContinueAsGuest: _continueAsGuest);
          },
        );
      },
    );
  }
}
