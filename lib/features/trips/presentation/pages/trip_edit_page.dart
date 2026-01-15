import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

class TripEditPage extends ConsumerStatefulWidget {
  final String? tripId;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  const TripEditPage({
    super.key,
    this.tripId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  });

  @override
  ConsumerState<TripEditPage> createState() => _TripEditPageState();
}

class _TripEditPageState extends ConsumerState<TripEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _resortController = TextEditingController();
  final _liveaboardController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  Trip? _originalTrip;

  bool get isEditing => widget.tripId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadTrip();
    }
    _nameController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    _resortController.addListener(_onFieldChanged);
    _liveaboardController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges && !_isLoading) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadTrip() async {
    setState(() => _isLoading = true);
    try {
      final trip = await ref
          .read(tripRepositoryProvider)
          .getTripById(widget.tripId!);
      if (trip != null && mounted) {
        _originalTrip = trip;
        _nameController.text = trip.name;
        _locationController.text = trip.location ?? '';
        _resortController.text = trip.resortName ?? '';
        _liveaboardController.text = trip.liveaboardName ?? '';
        _notesController.text = trip.notes;
        setState(() {
          _startDate = trip.startDate;
          _endDate = trip.endDate;
          _isLoading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading trip: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _resortController.dispose();
    _liveaboardController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    if (widget.embedded) {
      widget.onCancel?.call();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Trip Name *',
                      prefixIcon: Icon(Icons.flight_takeoff),
                      hintText: 'e.g., Red Sea Safari 2024',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a trip name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Date section header
                  Text(
                    'Trip Dates',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Start date
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Start Date'),
                    subtitle: Text(dateFormat.format(_startDate)),
                    onTap: () => _selectDate(context, true),
                    contentPadding: EdgeInsets.zero,
                    trailing: const Icon(Icons.edit),
                  ),

                  // End date
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('End Date'),
                    subtitle: Text(dateFormat.format(_endDate)),
                    onTap: () => _selectDate(context, false),
                    contentPadding: EdgeInsets.zero,
                    trailing: const Icon(Icons.edit),
                  ),

                  // Duration display
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Text(
                      '${_endDate.difference(_startDate).inDays + 1} days',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location section header
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location field
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.place),
                      hintText: 'e.g., Egypt, Red Sea',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Resort field
                  TextFormField(
                    controller: _resortController,
                    decoration: const InputDecoration(
                      labelText: 'Resort Name',
                      prefixIcon: Icon(Icons.hotel),
                      hintText: 'e.g., Marsa Shagra',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Liveaboard field
                  TextFormField(
                    controller: _liveaboardController,
                    decoration: const InputDecoration(
                      labelText: 'Liveaboard Name',
                      prefixIcon: Icon(Icons.sailing),
                      hintText: 'e.g., MY Blue Force One',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 24),

                  // Notes section header
                  Text(
                    'Notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes field
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.notes),
                      hintText: 'Any additional notes about this trip',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),

                  if (!widget.embedded) ...[
                    // Save button
                    FilledButton(
                      onPressed: _isSaving ? null : _saveTrip,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Update Trip' : 'Add Trip'),
                    ),

                    // Cancel button
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _confirmCancel(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
          );

    if (widget.embedded) {
      return PopScope(
        canPop: !_hasChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && _hasChanges) {
            final shouldPop = await _showDiscardDialog();
            if (shouldPop == true && mounted) {
              _handleCancel();
            }
          }
        },
        child: Column(
          children: [
            _buildEmbeddedHeader(context),
            Expanded(child: body),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Trip' : 'Add Trip'),
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton(onPressed: _saveTrip, child: const Text('Save')),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              isEditing ? Icons.edit : Icons.add,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Edit Trip' : 'Add Trip',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_hasChanges) {
                final discard = await _showDiscardDialog();
                if (discard == true && mounted) {
                  _handleCancel();
                }
              } else {
                _handleCancel();
              }
            },
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSaving ? null : _saveTrip,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = isStartDate ? DateTime(2000) : _startDate;
    final lastDate = DateTime(2100);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = pickedDate;
        }
        _hasChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      return await _showDiscardDialog() ?? false;
    }
    return true;
  }

  Future<void> _confirmCancel() async {
    if (_hasChanges) {
      final discard = await _showDiscardDialog();
      if (discard == true && mounted) {
        _handleCancel();
      }
    } else {
      _handleCancel();
    }
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final diverId =
          _originalTrip?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      final now = DateTime.now();
      final trip = Trip(
        id: widget.tripId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        resortName: _resortController.text.trim().isEmpty
            ? null
            : _resortController.text.trim(),
        liveaboardName: _liveaboardController.text.trim().isEmpty
            ? null
            : _liveaboardController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: _originalTrip?.createdAt ?? now,
        updatedAt: now,
      );

      String savedId;
      if (isEditing) {
        await ref.read(tripListNotifierProvider.notifier).updateTrip(trip);
        savedId = widget.tripId!;
      } else {
        final newTrip = await ref
            .read(tripListNotifierProvider.notifier)
            .addTrip(trip);
        savedId = newTrip.id;
      }

      if (mounted) {
        if (widget.embedded) {
          widget.onSaved?.call(savedId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? 'Trip updated successfully'
                    : 'Trip added successfully',
              ),
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving trip: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
