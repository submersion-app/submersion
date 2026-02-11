import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class SpeciesEditPage extends ConsumerStatefulWidget {
  final String? speciesId;

  const SpeciesEditPage({super.key, this.speciesId});

  bool get isEditing => speciesId != null;

  @override
  ConsumerState<SpeciesEditPage> createState() => _SpeciesEditPageState();
}

class _SpeciesEditPageState extends ConsumerState<SpeciesEditPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _commonNameController;
  late TextEditingController _scientificNameController;
  late TextEditingController _taxonomyClassController;
  late TextEditingController _descriptionController;
  SpeciesCategory _category = SpeciesCategory.fish;

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _commonNameController = TextEditingController();
    _scientificNameController = TextEditingController();
    _taxonomyClassController = TextEditingController();
    _descriptionController = TextEditingController();

    if (widget.isEditing) {
      _loadSpecies();
    }
  }

  Future<void> _loadSpecies() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(speciesRepositoryProvider);
      final species = await repository.getSpeciesById(widget.speciesId!);

      if (species != null && mounted) {
        setState(() {
          _commonNameController.text = species.commonName;
          _scientificNameController.text = species.scientificName ?? '';
          _taxonomyClassController.text = species.taxonomyClass ?? '';
          _descriptionController.text = species.description ?? '';
          _category = species.category;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.marineLife_speciesEdit_errorLoading(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _commonNameController.dispose();
    _scientificNameController.dispose();
    _taxonomyClassController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? context.l10n.marineLife_speciesEdit_editTitle
              : context.l10n.marineLife_speciesEdit_addTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.marineLife_speciesEdit_backTooltip,
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.marineLife_speciesEdit_saveButton),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _commonNameController,
                      decoration: InputDecoration(
                        labelText:
                            context.l10n.marineLife_speciesEdit_commonNameLabel,
                        hintText:
                            context.l10n.marineLife_speciesEdit_commonNameHint,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context
                              .l10n
                              .marineLife_speciesEdit_commonNameError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _scientificNameController,
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .marineLife_speciesEdit_scientificNameLabel,
                        hintText: context
                            .l10n
                            .marineLife_speciesEdit_scientificNameHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SpeciesCategory>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText:
                            context.l10n.marineLife_speciesEdit_categoryLabel,
                      ),
                      items: SpeciesCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxonomyClassController,
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .marineLife_speciesEdit_taxonomyClassLabel,
                        hintText: context
                            .l10n
                            .marineLife_speciesEdit_taxonomyClassHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .marineLife_speciesEdit_descriptionLabel,
                        hintText:
                            context.l10n.marineLife_speciesEdit_descriptionHint,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(speciesListNotifierProvider.notifier);
      final commonName = _commonNameController.text.trim();
      final scientificName = _scientificNameController.text.trim();
      final taxonomyClass = _taxonomyClassController.text.trim();
      final description = _descriptionController.text.trim();

      if (widget.isEditing) {
        final repository = ref.read(speciesRepositoryProvider);
        final existing = await repository.getSpeciesById(widget.speciesId!);
        if (existing != null) {
          await notifier.updateSpecies(
            existing.copyWith(
              commonName: commonName,
              scientificName: scientificName.isEmpty ? null : scientificName,
              category: _category,
              taxonomyClass: taxonomyClass.isEmpty ? null : taxonomyClass,
              description: description.isEmpty ? null : description,
            ),
          );
        }
      } else {
        await notifier.addSpecies(
          commonName: commonName,
          scientificName: scientificName.isEmpty ? null : scientificName,
          category: _category,
          taxonomyClass: taxonomyClass.isEmpty ? null : taxonomyClass,
          description: description.isEmpty ? null : description,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? context.l10n.marineLife_speciesEdit_updatedSnackbar(
                      commonName,
                    )
                  : context.l10n.marineLife_speciesEdit_addedSnackbar(
                      commonName,
                    ),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.marineLife_speciesEdit_errorSaving(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
