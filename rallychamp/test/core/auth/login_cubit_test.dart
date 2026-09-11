import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/core/auth/auth_repository.dart';
import 'package:rallychamp/core/auth/login_cubit.dart';
import 'package:rallychamp/core/auth/login_state.dart';

class _FakeAuthRepository implements AuthRepository {
  bool shouldThrow = false;
  String? failWithCode;
  String? lastEmail;
  bool? lastWasSignUp;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<void> signInWithGoogle() async {
    if (shouldThrow) throw Exception('google sign-in failed');
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldThrow) {
      throw FirebaseAuthException(code: failWithCode ?? 'wrong-password');
    }
    lastEmail = email;
    lastWasSignUp = false;
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldThrow) {
      throw FirebaseAuthException(
        code: failWithCode ?? 'email-already-in-use',
      );
    }
    lastEmail = email;
    lastWasSignUp = true;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  group('LoginCubit', () {
    test('starts idle', () {
      final cubit = LoginCubit(_FakeAuthRepository());
      expect(cubit.state, isA<LoginIdle>());
      cubit.close();
    });

    test('ends in Success and delegates a sign-up to the repository', () async {
      final repo = _FakeAuthRepository();
      final cubit = LoginCubit(repo);

      await cubit.submitEmail(
        email: 'ana@example.com',
        password: 'password1',
        isSignUp: true,
      );

      expect(cubit.state, isA<LoginSuccess>());
      expect(repo.lastEmail, 'ana@example.com');
      expect(repo.lastWasSignUp, true);

      await cubit.close();
    });

    test('ends in Success and delegates a sign-in to the repository', () async {
      final repo = _FakeAuthRepository();
      final cubit = LoginCubit(repo);

      await cubit.submitEmail(
        email: 'ana@example.com',
        password: 'password1',
        isSignUp: false,
      );

      expect(cubit.state, isA<LoginSuccess>());
      expect(repo.lastWasSignUp, false);

      await cubit.close();
    });

    test('emits a friendly Failure message for a bad password', () async {
      final repo = _FakeAuthRepository()..shouldThrow = true;
      final cubit = LoginCubit(repo);

      await cubit.submitEmail(
        email: 'ana@example.com',
        password: 'wrong',
        isSignUp: false,
      );

      expect(cubit.state, isA<LoginFailure>());
      expect(
        (cubit.state as LoginFailure).message,
        contains('Incorrect email or password'),
      );

      await cubit.close();
    });

    test('emits a friendly Failure message for an existing account', () async {
      final repo = _FakeAuthRepository()..shouldThrow = true;
      final cubit = LoginCubit(repo);

      await cubit.submitEmail(
        email: 'ana@example.com',
        password: 'password1',
        isSignUp: true,
      );

      expect(cubit.state, isA<LoginFailure>());
      expect(
        (cubit.state as LoginFailure).message,
        contains('already exists'),
      );

      await cubit.close();
    });

    test('emits Failure when Google sign-in fails', () async {
      final repo = _FakeAuthRepository()..shouldThrow = true;
      final cubit = LoginCubit(repo);

      await cubit.signInWithGoogle();

      expect(cubit.state, isA<LoginFailure>());

      await cubit.close();
    });
  });
}
