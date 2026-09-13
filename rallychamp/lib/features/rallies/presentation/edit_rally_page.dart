import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/rally_repository.dart';
import '../data/rally_summary.dart';

/// Corrects a rally's details after creation. Everything the create form
/// asks for is editable here *except* the stage count — stages are real
/// documents by now, with routes drawn on them and checkpoints assigned to
/// them, so adding or removing one belongs on the Stages page where you
/// can see what you'd be destroying. Publishing and the live status have
/// their own deliberate controls too, and deliberately aren't here.
class EditRallyPage extends StatefulWidget {
  const EditRallyPage({super.key, required this.rally});

  final RallySummary rally;

  @override
  State<EditRallyPage> createState() => _EditRallyPageState();
}

class _EditRallyPageState extends State<EditRallyPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.rally.name);
  late final _descriptionController = TextEditingController(
    text: widget.rally.description,
  );
  late final _locationController = TextEditingController(
    text: widget.rally.locationName,
  );
  late final _phoneController = TextEditingController(
    text: widget.rally.organizerPhone ?? '',
  );

  late DateTime? _startDate = widget.rally.startDate;
  late DateTime? _endDate = widget.rally.endDate;
  late bool _allowWalkupMarshals = widget.rally.allowWalkupMarshals;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    // Unlike the create form, this one can't floor the range at today: a
    // rally that already ran still has to be correctable, and clamping to
    // the future would make its real dates unpickable.
    final current = isStart ? _startDate : _endDate;
    final anchor = current ?? _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_startDate == null || _endDate == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pick a start and end date.')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('End date must be on or after the start date.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await RallyRepository().updateRallyDetails(
        rallyId: widget.rally.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        locationName: _locationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        allowWalkupMarshals: _allowWalkupMarshals,
        organizerPhone: _phoneController.text,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Rally details updated.')),
      );
      navigator.pop(true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit rally')),
      body: Form(
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
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Organizer phone (optional)',
                helperText: 'Shown to everyone following the rally, so they '
                    'can call you. Leave blank to hide it.',
                helperMaxLines: 3,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow walk-up marshals'),
              subtitle: const Text(
                'On = anyone who applies as a marshal while the rally '
                'is running is accepted immediately, no review needed',
              ),
              value: _allowWalkupMarshals,
              onChanged: (v) => setState(() => _allowWalkupMarshals = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
