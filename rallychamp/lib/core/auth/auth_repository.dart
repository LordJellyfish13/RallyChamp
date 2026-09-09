import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleSignInInitialized = false;

  Future<User> signInWithGoogle() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user!;
  }
}
