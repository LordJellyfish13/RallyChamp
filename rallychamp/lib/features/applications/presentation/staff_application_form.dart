import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/active_rally/my_rallies_store.dart';
import '../../../core/auth/auth_repository.dart';
import '../bloc/application_cubit.dart';
import '../bloc/application_state.dart';
import '../data/applications_repository.dart';
import '../data/staff_role.dart';

/// Assumes the caller already ensured a signed-in session (via
/// `ensureSignedIn`/`LoginPage`) before pushing this — it only collects the
/// role-specific profile fields, not identity.
class StaffApplicationForm extends StatelessWidget {
  const StaffApplicationForm({
    super.key,
    required this.rallyId,
    required this.role,
  });

  final String rallyId;
  final StaffRole role;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ApplicationCubit(ApplicationsRepository()),
      child: _StaffApplicationFormView(rallyId: rallyId, role: role),
    );
  }
}

class _StaffApplicationFormView extends StatefulWidget {
  const _StaffApplicationFormView({
    required this.rallyId,
    required this.role,
  });

  final String rallyId;
  final StaffRole role;

  @override
  State<_StaffApplicationFormView> createState() =>
      _StaffApplicationFormViewState();
}

class _StaffApplicationFormViewState
    extends State<_StaffApplicationFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _oibController = TextEditingController();
  final _licenseController = TextEditingController();

  /// What the name field started as (the Google account's display name, or
  /// blank) — kept so [_loadProfile] can tell "still the auto-filled
  /// value" apart from "the user already typed something else", since
  /// unlike the other fields this one doesn't start empty.
  String _authDisplayName = '';

  @override
  void initState() {
    super.initState();
    _authDisplayName = AuthRepository().currentUser?.displayName ?? '';
    _nameController.text = _authDisplayName;
    _loadProfile();
  }

  /// Prefills every field from `users/{uid}` if this isn't the user's
  /// first application — still fully editable, so a stale or wrong stored
  /// value is a two-second fix, not a retype from scratch. Each field is
  /// guarded against overwriting something the user already typed while
  /// this (async, possibly slow on a cold start) read was in flight: the
  /// others check for still-empty, and the name field — which starts
  /// non-empty from the account's display name — checks it still matches
  /// that starting value, since a stored profile name (given explicitly on
  /// a past application) is more likely correct than a Google account name
  /// that might be a nickname or a shared family account.
  Future<void> _loadProfile() async {
    final profile = await ApplicationsRepository().getMyProfile();
    if (!mounted || profile == null) return;
    setState(() {
      if (profile.name != null && _nameController.text == _authDisplayName) {
        _nameController.text = profile.name!;
      }
      if (_phoneController.text.isEmpty && profile.phone != null) {
        _phoneController.text = profile.phone!;
      }
      if (_oibController.text.isEmpty && profile.oib != null) {
        _oibController.text = profile.oib!;
      }
      if (_licenseController.text.isEmpty && profile.licenseNumber != null) {
        _licenseController.text = profile.licenseNumber!;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _oibController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ApplicationCubit>().submitStaff(
      rallyId: widget.rallyId,
      role: widget.role,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      oib: _oibController.text.trim(),
      licenseNumber: widget.role == StaffRole.judge
          ? _licenseController.text.trim()
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthRepository().currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('Apply as ${widget.role.label}')),
      body: BlocConsumer<ApplicationCubit, ApplicationState>(
        listener: (context, state) {
          if (state is ApplicationSuccess) {
            MyRalliesStore.recordVisit(widget.rallyId);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Application submitted!')),
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
                Text(
                  'Applying as $email',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                if (widget.role == StaffRole.judge) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Judge license number',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required for judges'
                        : null,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: submitting ? null : _submit,
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit application'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
