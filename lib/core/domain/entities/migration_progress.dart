class MigrationProgress {
  final int currentStep;
  final int totalSteps;

  const MigrationProgress({
    required this.currentStep,
    required this.totalSteps,
  });

  double get fraction => totalSteps > 0 ? currentStep / totalSteps : 0.0;
}
