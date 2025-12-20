import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../divers/domain/entities/diver.dart';
import '../../../divers/presentation/providers/diver_providers.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final diver = Diver(
        id: '',
        name: _nameController.text.trim(),
        emergencyContact: const EmergencyContact(),
        insurance: const DiverInsurance(),
        medicalNotes: '',
        notes: '',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );

      final newDiver =
          await ref.read(diverListNotifierProvider.notifier).addDiver(diver);

      // Set as current diver
      await ref
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(newDiver.id);

      if (mounted) {
        // Navigate to main app
        context.go('/dives');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating profile: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App icon/logo
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.scuba_diving,
                      size: 64,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Welcome text
                  Text(
                    'Welcome to Submersion',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Your personal dive logging companion',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Profile creation card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Create Your Profile',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your name to get started. You can add more details later.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),

                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Your Name',
                                prefixIcon: Icon(Icons.person),
                                hintText: 'Enter your name',
                              ),
                              textCapitalization: TextCapitalization.words,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _createProfile(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            FilledButton.icon(
                              onPressed: _isSaving ? null : _createProfile,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward),
                              label: Text(
                                _isSaving ? 'Creating...' : 'Get Started',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
