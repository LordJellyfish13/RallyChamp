import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/active_rally/my_rallies_store.dart';
import '../../../core/auth/auth_repository.dart';
import '../bloc/application_cubit.dart';
import '../bloc/application_state.dart';
import '../data/applications_repository.dart';

/// Assumes the caller already ensured a signed-in session (via
/// `ensureSignedIn`/`LoginPage`) before pushing this — it only collects the
/// entry-specific fields, not identity.
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
  final _teamNameController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _coDriverNameController = TextEditingController();
  final _carNumberController = TextEditingController();
  final _carClassController = TextEditingController();
  final _phoneController = TextEditingController();
  final _oibController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = AuthRepository().currentUser;
    _driverNameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _driverNameController.dispose();
    _coDriverNameController.dispose();
    _carNumberController.dispose();
    _carClassController.dispose();
    _phoneController.dispose();
    _oibController.dispose();
    super.dispose();
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
      phone: _phoneController.text.trim(),
      oib: _oibController.text.trim(),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final email = AuthRepository().currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Enter as Team / Competitor')),
      body: BlocConsumer<ApplicationCubit, ApplicationState>(
        listener: (context, state) {
          if (state is ApplicationSuccess) {
            MyRalliesStore.recordVisit(widget.rallyId);
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
                Text(
                  'Entering as $email',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 12),
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
