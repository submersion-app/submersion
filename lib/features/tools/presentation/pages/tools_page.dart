import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tools landing page displaying all available diving calculators.
///
/// Provides easy navigation to specialized calculators:
/// - Deco Calculator: Dive planning with decompression stops
/// - Gas Calculators: MOD, Best Mix, Gas Consumption, Rock Bottom
/// - Weight Calculator: Recommended dive weight based on equipment
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Deco Calculator Card
          _ToolCard(
            icon: Icons.calculate,
            iconColor: colorScheme.primary,
            title: 'Deco Calculator',
            subtitle: 'Plan dives with decompression stops',
            description:
                'Calculate no-decompression limits, required deco stops, '
                'and CNS/OTU exposure for multi-level dive profiles.',
            onTap: () => context.go('/tools/deco-calculator'),
          ),
          const SizedBox(height: 12),

          // Gas Calculators Card
          _ToolCard(
            icon: Icons.science,
            iconColor: colorScheme.tertiary,
            title: 'Gas Calculators',
            subtitle: 'MOD, Best Mix, Consumption, Rock Bottom',
            description:
                'Four specialized gas calculators:\n'
                '• MOD - Maximum operating depth for a gas mix\n'
                '• Best Mix - Ideal O₂% for a target depth\n'
                '• Consumption - Gas usage estimation\n'
                '• Rock Bottom - Emergency reserve calculation',
            onTap: () => context.go('/tools/gas-calculators'),
          ),
          const SizedBox(height: 12),

          // Weight Calculator Card
          _ToolCard(
            icon: Icons.fitness_center,
            iconColor: colorScheme.secondary,
            title: 'Weight Calculator',
            subtitle: 'Recommended weight for your setup',
            description:
                'Estimate the weight you need based on your exposure suit, '
                'tank material, water type, and body weight.',
            onTap: () => context.go('/tools/weight-calculator'),
          ),
          const SizedBox(height: 24),

          // Info Card
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These calculators are for planning purposes only. '
                      'Always verify calculations and follow your dive training.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card widget displaying a tool with icon, title, description and tap action.
class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
