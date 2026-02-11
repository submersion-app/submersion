import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_picker.dart';

class CourseEditPage extends ConsumerStatefulWidget {
  final String? courseId;
  final bool embedded;
  final VoidCallback? onSaved;
  final void Function(String savedId)? onSavedWithId;
  final VoidCallback? onCancel;

  const CourseEditPage({
    super.key,
    this.courseId,
    this.embedded = false,
    this.onSaved,
    this.onSavedWithId,
    this.onCancel,
  });

  @override
  ConsumerState<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends ConsumerState<CourseEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructorNameController = TextEditingController();
  final _instructorNumberController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  CertificationAgency _agency = CertificationAgency.padi;
  DateTime _startDate = DateTime.now();
  DateTime? _completionDate;
  String? _instructorId;
  Certification? _selectedCertification;
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get _isEditing => widget.courseId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _instructorNameController.dispose();
    _instructorNumberController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initializeFromCourse(Course course) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = course.name;
    _agency = course.agency;
    _startDate = course.startDate;
    _completionDate = course.completionDate;
    _instructorId = course.instructorId;
    _instructorNameController.text = course.instructorName ?? '';
    _instructorNumberController.text = course.instructorNumber ?? '';
    _locationController.text = course.location ?? '';
    _notesController.text = course.notes;

    // Load linked certification if exists
    if (course.certificationId != null) {
      _loadCertification(course.certificationId!);
    }
  }

  Future<void> _loadCertification(String certificationId) async {
    final certification = await ref.read(
      certificationByIdProvider(certificationId).future,
    );
    if (mounted && certification != null) {
      setState(() => _selectedCertification = certification);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final courseAsync = ref.watch(courseByIdProvider(widget.courseId!));
      return courseAsync.when(
        data: (course) {
          if (course == null) {
            return _buildNotFound();
          }
          _initializeFromCourse(course);
          return _buildForm(context, course);
        },
        loading: () => _buildLoading(),
        error: (error, stack) => _buildError(error),
      );
    }

    return _buildForm(context, null);
  }

  Widget _buildForm(BuildContext context, Course? existingCourse) {
    final colorScheme = Theme.of(context).colorScheme;
    final buddiesAsync = ref.watch(allBuddiesProvider);

    final form = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Course name
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.courses_field_courseName,
              hintText: context.l10n.courses_field_courseNameHint,
              prefixIcon: const Icon(Icons.school),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.courses_validation_nameRequired;
              }
              return null;
            },
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Agency
          DropdownButtonFormField<CertificationAgency>(
            initialValue: _agency,
            decoration: InputDecoration(
              labelText: context.l10n.courses_label_agency,
              prefixIcon: const Icon(Icons.business),
            ),
            items: CertificationAgency.values.map((agency) {
              return DropdownMenuItem(
                value: agency,
                child: Text(agency.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _agency = value);
              }
            },
          ),
          const SizedBox(height: 16),

          // Start date
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(context.l10n.courses_label_startDate),
            subtitle: Text(DateFormat.yMMMd().format(_startDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectDate(context, isStart: true),
          ),
          const Divider(),

          // Completion date
          SwitchListTile(
            secondary: const Icon(Icons.check_circle),
            title: Text(context.l10n.courses_label_completed),
            subtitle: _completionDate != null
                ? Text(DateFormat.yMMMd().format(_completionDate!))
                : Text(context.l10n.courses_label_courseInProgress),
            value: _completionDate != null,
            onChanged: (value) {
              setState(() {
                _completionDate = value ? DateTime.now() : null;
              });
            },
          ),
          if (_completionDate != null) ...[
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(context.l10n.courses_label_completionDate),
              subtitle: Text(DateFormat.yMMMd().format(_completionDate!)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDate(context, isStart: false),
            ),
          ],
          const Divider(),
          const SizedBox(height: 8),

          // Instructor section header
          Row(
            children: [
              Icon(Icons.person, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.courses_section_instructor,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Instructor from buddies (optional)
          buddiesAsync.when(
            data: (buddies) {
              final instructors = buddies
                  .where((b) => b.certificationLevel != null)
                  .toList();
              if (instructors.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: _instructorId,
                    decoration: InputDecoration(
                      labelText: context.l10n.courses_field_selectFromBuddies,
                      prefixIcon: const Icon(Icons.people),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(context.l10n.courses_label_none),
                      ),
                      ...instructors.map((buddy) {
                        return DropdownMenuItem(
                          value: buddy.id,
                          child: Text(buddy.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _instructorId = value;
                        if (value != null) {
                          final buddy = instructors.firstWhere(
                            (b) => b.id == value,
                          );
                          _instructorNameController.text = buddy.displayName;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),

          // Instructor name (manual)
          TextFormField(
            controller: _instructorNameController,
            decoration: InputDecoration(
              labelText: context.l10n.courses_field_instructorName,
              prefixIcon: const Icon(Icons.badge),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Instructor number
          TextFormField(
            controller: _instructorNumberController,
            decoration: InputDecoration(
              labelText: context.l10n.courses_field_instructorNumber,
              prefixIcon: const Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 16),

          // Location
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: context.l10n.courses_field_location,
              prefixIcon: const Icon(Icons.place),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: context.l10n.courses_field_notes,
              prefixIcon: const Icon(Icons.notes),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          // Earned Certification (link course to certification)
          Row(
            children: [
              Icon(Icons.card_membership, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.courses_section_earnedCertification,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.courses_field_linkCertificationHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          CertificationPicker(
            selectedCertification: _selectedCertification,
            onCertificationSelected: (cert) {
              setState(() => _selectedCertification = cert);
            },
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : () => _save(existingCourse),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditing
                          ? context.l10n.courses_action_saveChanges
                          : context.l10n.courses_action_create,
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context),
          Expanded(child: form),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? context.l10n.courses_title_edit
              : context.l10n.courses_title_new,
        ),
        actions: [
          Semantics(
            button: true,
            label: context.l10n.courses_action_saveSemantic,
            child: TextButton(
              onPressed: _isLoading ? null : () => _save(existingCourse),
              child: Text(context.l10n.common_action_save),
            ),
          ),
        ],
      ),
      body: form,
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing
                  ? context.l10n.courses_title_edit
                  : context.l10n.courses_title_new,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (widget.onCancel != null)
            TextButton(
              onPressed: widget.onCancel,
              child: Text(context.l10n.common_action_cancel),
            ),
          TextButton(
            onPressed: _isLoading ? null : () => _save(null),
            child: Text(context.l10n.common_action_save),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    required bool isStart,
  }) async {
    final initialDate = isStart
        ? _startDate
        : (_completionDate ?? DateTime.now());
    final firstDate = isStart ? DateTime(2000) : _startDate;
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Adjust completion date if it's before start date
          if (_completionDate != null && _completionDate!.isBefore(picked)) {
            _completionDate = picked;
          }
        } else {
          _completionDate = picked;
        }
      });
    }
  }

  Future<void> _save(Course? existingCourse) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);

      final course = Course(
        id: existingCourse?.id ?? '',
        diverId: diverId ?? existingCourse?.diverId ?? '',
        name: _nameController.text.trim(),
        agency: _agency,
        startDate: _startDate,
        completionDate: _completionDate,
        certificationId: _selectedCertification?.id,
        instructorId: _instructorId,
        instructorName: _instructorNameController.text.trim().isEmpty
            ? null
            : _instructorNameController.text.trim(),
        instructorNumber: _instructorNumberController.text.trim().isEmpty
            ? null
            : _instructorNumberController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: existingCourse?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      String savedId;
      final notifier = ref.read(courseListNotifierProvider.notifier);
      if (_isEditing) {
        await notifier.updateCourse(course);
        ref.invalidate(courseByIdProvider(course.id));
        savedId = course.id;
      } else {
        final newCourse = await notifier.addCourse(course);
        savedId = newCourse.id;
      }

      // Link/unlink certification bidirectionally
      final oldCertId = existingCourse?.certificationId;
      final newCertId = _selectedCertification?.id;
      if (oldCertId != newCertId) {
        if (newCertId != null) {
          // Link to new certification
          await notifier.linkCourseToCertification(savedId, newCertId);
        }
        // Invalidate old certification's course provider if changed
        if (oldCertId != null) {
          ref.invalidate(courseForCertificationProvider(oldCertId));
        }
      }

      if (widget.onSavedWithId != null) {
        widget.onSavedWithId!(savedId);
      } else if (widget.onSaved != null) {
        widget.onSaved!();
      } else if (mounted) {
        // Navigate explicitly to detail page instead of pop()
        // This ensures consistent navigation regardless of navigation stack state
        context.go('/courses/$savedId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.courses_message_errorSaving(e.toString()),
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

  Widget _buildLoading() {
    if (widget.embedded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.courses_title_edit)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildNotFound() {
    if (widget.embedded) {
      return Center(child: Text(context.l10n.courses_detail_notFound));
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.courses_title_edit)),
      body: Center(child: Text(context.l10n.courses_detail_notFound)),
    );
  }

  Widget _buildError(Object error) {
    final content = Center(
      child: Text(context.l10n.courses_error_generic(error.toString())),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.courses_title_edit)),
      body: content,
    );
  }
}
