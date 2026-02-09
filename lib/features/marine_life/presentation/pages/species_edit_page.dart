import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

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
            content: Text('Error loading species: $e'),
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
        title: Text(widget.isEditing ? 'Edit Species' : 'Add Species'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                : const Text('Save'),
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
                      decoration: const InputDecoration(
                        labelText: 'Common Name',
                        hintText: 'e.g., Ocellaris Clownfish',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a common name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _scientificNameController,
                      decoration: const InputDecoration(
                        labelText: 'Scientific Name',
                        hintText: 'e.g., Amphiprion ocellaris',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SpeciesCategory>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
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
                      decoration: const InputDecoration(
                        labelText: 'Taxonomy Class',
                        hintText: 'e.g., Actinopterygii',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Brief description of the species...',
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
                  ? 'Updated "$commonName"'
                  : 'Added "$commonName"',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving species: $e'),
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
