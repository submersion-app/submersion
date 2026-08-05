import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Minimal form for adding a user hyperbaric chamber entry.
class AddChamberPage extends ConsumerStatefulWidget {
  const AddChamberPage({super.key});

  @override
  ConsumerState<AddChamberPage> createState() => _AddChamberPageState();
}

class _AddChamberPageState extends ConsumerState<AddChamberPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _city.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addChamber_title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.addChamber_name),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.addChamber_nameRequired
                  : null,
            ),
            TextFormField(
              controller: _country,
              decoration: InputDecoration(labelText: l10n.addChamber_country),
              textCapitalization: TextCapitalization.characters,
              // A 2-letter ISO code; the same-country sort compares against
              // upper-case ISO codes, so cap the length to steer input.
              maxLength: 2,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.addChamber_countryRequired
                  : null,
            ),
            TextFormField(
              controller: _city,
              decoration: InputDecoration(labelText: l10n.addChamber_city),
            ),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: l10n.addChamber_phone),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.addChamber_phoneRequired
                  : null,
            ),
            TextFormField(
              controller: _notes,
              decoration: InputDecoration(labelText: l10n.addChamber_notes),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l10n.addChamber_save)),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    await ref
        .read(emergencyChamberRepositoryProvider)
        .createChamber(
          name: _name.text.trim(),
          country: _country.text.trim().toUpperCase(),
          phone: _phone.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          diverId: diverId,
        );
    if (mounted) context.pop();
  }
}
