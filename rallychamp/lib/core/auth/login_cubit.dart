import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_repository.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginIdle());

  final AuthRepository _repository;

  Future<void> signInWithGoogle() async {
    emit(const LoginSubmitting());
    try {
      await _repository.signInWithGoogle();
      emit(const LoginSuccess());
    } catch (e) {
      emit(LoginFailure(_mapError(e)));
    }
  }

  Future<void> submitEmail({
    required String email,
    required String password,
    required bool isSignUp,
  }) async {
    emit(const LoginSubmitting());
    try {
      if (isSignUp) {
        await _repository.signUpWithEmail(email: email, password: password);
      } else {
        await _repository.signInWithEmail(email: email, password: password);
      }
      emit(const LoginSuccess());
    } catch (e) {
      emit(LoginFailure(_mapError(e)));
    }
  }

  String _mapError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'weak-password':
          return 'Password is too weak (use at least 6 characters).';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    return '$error';
  }
}
