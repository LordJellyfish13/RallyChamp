import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/application_cubit.dart';
import '../bloc/application_state.dart';
import '../data/applications_repository.dart';
import '../data/staff_role.dart';

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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _oibController = TextEditingController();
  final _licenseController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      oib: _oibController.text.trim(),
      licenseNumber: widget.role == StaffRole.judge
          ? _licenseController.text.trim()
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Apply as ${widget.role.label}')),
      body: BlocConsumer<ApplicationCubit, ApplicationState>(
        listener: (context, state) {
          if (state is ApplicationSuccess) {
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
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
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
