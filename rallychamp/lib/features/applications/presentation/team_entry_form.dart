import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../bloc/application_cubit.dart';
import '../bloc/application_state.dart';
import '../data/applications_repository.dart';

class TeamEntryForm extends StatelessWidget {
  const TeamEntryForm({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ApplicationCubit(ApplicationsRepository()),
      child: _TeamEntryFormView(rallyId: rallyId),
    );
  }
}

class _TeamEntryFormView extends StatefulWidget {
  const _TeamEntryFormView({required this.rallyId});

  final String rallyId;

  @override
  State<_TeamEntryFormView> createState() => _TeamEntryFormViewState();
}

class _TeamEntryFormViewState extends State<_TeamEntryFormView> {
  final _formKey = GlobalKey<FormState>();
  final _authRepository = AuthRepository();
  final _teamNameController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _coDriverNameController = TextEditingController();
  final _carNumberController = TextEditingController();
  final _carClassController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _oibController = TextEditingController();

  bool _signedInWithGoogle = false;
  bool _googleSigningIn = false;
  String? _googleError;

  @override
  void dispose() {
    _teamNameController.dispose();
    _driverNameController.dispose();
    _coDriverNameController.dispose();
    _carNumberController.dispose();
    _carClassController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _oibController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleSigningIn = true;
      _googleError = null;
    });
    try {
      final user = await _authRepository.signInWithGoogle();
      _emailController.text = user.email ?? '';
      if (_driverNameController.text.isEmpty) {
        _driverNameController.text = user.displayName ?? '';
      }
      setState(() => _signedInWithGoogle = true);
    } catch (e) {
      setState(() => _googleError = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _googleSigningIn = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ApplicationCubit>().submitTeam(
      rallyId: widget.rallyId,
      teamName: _teamNameController.text.trim(),
      driverName: _driverNameController.text.trim(),
      coDriverName: _coDriverNameController.text.trim(),
      carNumber: _carNumberController.text.trim(),
      carClass: _carClassController.text.trim(),
      email: _emailController.text.trim(),
      password: _signedInWithGoogle ? null : _passwordController.text,
      phone: _phoneController.text.trim(),
      oib: _oibController.text.trim(),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter as Team / Competitor')),
      body: BlocConsumer<ApplicationCubit, ApplicationState>(
        listener: (context, state) {
          if (state is ApplicationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Entry submitted!')),
            );
            Navigator.of(context).pop();
          } else if (state is ApplicationFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          final submitting = state is ApplicationSubmitting;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _teamNameController,
                  decoration: const InputDecoration(labelText: 'Team name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _driverNameController,
                  decoration: const InputDecoration(labelText: 'Driver name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _coDriverNameController,
                  decoration: const InputDecoration(
                    labelText: 'Co-driver name',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _carNumberController,
                  decoration: const InputDecoration(labelText: 'Car number'),
                  keyboardType: TextInputType.number,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _carClassController,
                  decoration: const InputDecoration(labelText: 'Class'),
                  validator: _required,
                ),
                const Divider(height: 32),
                if (_signedInWithGoogle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Signed in as ${_emailController.text}',
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _googleSigningIn ? null : _signInWithGoogle,
                    icon: _googleSigningIn
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                  if (_googleError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _googleError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
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
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _oibController,
                  decoration: const InputDecoration(labelText: 'OIB'),
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.length != 11 || int.tryParse(value) == null) {
                      return 'OIB must be 11 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: submitting ? null : _submit,
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit entry'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
