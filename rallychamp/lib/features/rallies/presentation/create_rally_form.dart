import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/create_rally_cubit.dart';
import '../bloc/create_rally_state.dart';
import '../data/rally_repository.dart';

class CreateRallyForm extends StatelessWidget {
  const CreateRallyForm({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreateRallyCubit(RallyRepository()),
      child: const _CreateRallyFormView(),
    );
  }
}

class _CreateRallyFormView extends StatefulWidget {
  const _CreateRallyFormView();

  @override
  State<_CreateRallyFormView> createState() => _CreateRallyFormViewState();
}

class _CreateRallyFormViewState extends State<_CreateRallyFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _stageCountController = TextEditingController(text: '1');

  DateTime? _startDate;
  DateTime? _endDate;
  bool _publishImmediately = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _stageCountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // End date can't be before whichever start date is currently chosen;
    // neither can be in the past.
    final earliest = isStart ? today : (_startDate ?? today);
    final current = isStart ? _startDate : _endDate;
    final initialDate = (current != null && !current.isBefore(earliest))
        ? current
        : earliest;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: earliest,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        // The previously chosen end date may now be before the new start
        // date — clear it rather than leave an invalid combination.
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a start and end date.')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be on or after the start date.')),
      );
      return;
    }
    context.read<CreateRallyCubit>().submit(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      locationName: _locationController.text.trim(),
      startDate: _startDate!,
      endDate: _endDate!,
      stageCount: int.parse(_stageCountController.text.trim()),
      publishImmediately: _publishImmediately,
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(title: const Text('Create Rally')),
      body: BlocConsumer<CreateRallyCubit, CreateRallyState>(
        listener: (context, state) {
          if (state is CreateRallySuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _publishImmediately
                      ? 'Rally created and published!'
                      : 'Rally created as a draft.',
                ),
              ),
            );
            Navigator.of(context).pop();
          } else if (state is CreateRallyFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          final submitting = state is CreateRallySubmitting;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Rally name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g. Risnjak National Park',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(isStart: true),
                        child: Text(
                          _startDate == null
                              ? 'Start date'
                              : dateFormat.format(_startDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(isStart: false),
                        child: Text(
                          _endDate == null
                              ? 'End date'
                              : dateFormat.format(_endDate!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stageCountController,
                  decoration: const InputDecoration(
                    labelText: 'Number of stages',
                    helperText: 'Leave at 1 if this rally has no special stages',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1) return 'Enter at least 1';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publish immediately'),
                  subtitle: const Text(
                    'Off = saved as a private draft you can build out first',
                  ),
                  value: _publishImmediately,
                  onChanged: (v) => setState(() => _publishImmediately = v),
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
                      : const Text('Create rally'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
