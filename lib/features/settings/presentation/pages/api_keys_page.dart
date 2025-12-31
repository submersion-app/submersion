import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/tide_service.dart';
import '../../../../core/services/weather_service.dart';
import '../../../dive_sites/data/services/dive_site_api_service.dart';
import '../providers/api_key_providers.dart';

class ApiKeysPage extends ConsumerStatefulWidget {
  const ApiKeysPage({super.key});

  @override
  ConsumerState<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends ConsumerState<ApiKeysPage> {
  final _weatherKeyController = TextEditingController();
  final _tideKeyController = TextEditingController();
  final _rapidApiKeyController = TextEditingController();
  bool _weatherKeyObscured = true;
  bool _tideKeyObscured = true;
  bool _rapidApiKeyObscured = true;
  bool _testingWeather = false;
  bool _testingTide = false;
  bool _testingRapidApi = false;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    // Listen for when keys finish loading and populate controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen<ApiKeyState>(apiKeyProvider, (previous, next) {
        // Only populate controllers once when loading completes
        if (previous?.isLoading == true && !next.isLoading && !_controllersInitialized) {
          _populateControllers(next);
        }
      });
      // Also check if already loaded
      final apiKeys = ref.read(apiKeyProvider);
      if (!apiKeys.isLoading && !_controllersInitialized) {
        _populateControllers(apiKeys);
      }
    });
  }

  void _populateControllers(ApiKeyState apiKeys) {
    _controllersInitialized = true;
    _weatherKeyController.text = apiKeys.openWeatherMapKey ?? '';
    _tideKeyController.text = apiKeys.worldTidesKey ?? '';
    _rapidApiKeyController.text = apiKeys.rapidApiKey ?? '';
  }

  @override
  void dispose() {
    _weatherKeyController.dispose();
    _tideKeyController.dispose();
    _rapidApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveWeatherKey() async {
    final key = _weatherKeyController.text.trim();
    final (success, error) = await ref
        .read(apiKeyProvider.notifier)
        .setOpenWeatherMapKey(key.isEmpty ? null : key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Weather API key saved' : (error ?? 'Save failed')),
          backgroundColor: success ? null : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveTideKey() async {
    final key = _tideKeyController.text.trim();
    final (success, error) = await ref
        .read(apiKeyProvider.notifier)
        .setWorldTidesKey(key.isEmpty ? null : key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Tide API key saved' : (error ?? 'Save failed')),
          backgroundColor: success ? null : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveRapidApiKey() async {
    final key = _rapidApiKeyController.text.trim();
    final (success, error) = await ref
        .read(apiKeyProvider.notifier)
        .setRapidApiKey(key.isEmpty ? null : key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'RapidAPI key saved' : (error ?? 'Save failed')),
          backgroundColor: success ? null : Colors.red,
        ),
      );
    }
  }

  Future<void> _testRapidApiKey() async {
    final key = _rapidApiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an API key first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _testingRapidApi = true);

    final service = DiveSiteApiService();
    final (isValid, errorMessage) = await service.testApiKeyWithDetails(key);

    if (mounted) {
      setState(() => _testingRapidApi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isValid ? 'API key is valid!' : (errorMessage ?? 'Unknown error')),
          backgroundColor: isValid ? Colors.green : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _testWeatherKey() async {
    final key = _weatherKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an API key first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _testingWeather = true);

    final isValid = await WeatherService.instance.testApiKey(key);

    if (mounted) {
      setState(() => _testingWeather = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isValid ? 'API key is valid!' : 'Invalid API key'),
          backgroundColor: isValid ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _testTideKey() async {
    final key = _tideKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an API key first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _testingTide = true);

    final isValid = await TideService.instance.testApiKey(key);

    if (mounted) {
      setState(() => _testingTide = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isValid ? 'API key is valid!' : 'Invalid API key'),
          backgroundColor: isValid ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apiKeys = ref.watch(apiKeyProvider);

    if (apiKeys.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('API Keys')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Configure API keys to enable weather data, tide information, and online dive site search.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // OpenWeatherMap Section
          _buildApiKeyCard(
            context,
            title: 'OpenWeatherMap',
            subtitle: 'Weather conditions, air temperature, visibility',
            icon: Icons.cloud,
            controller: _weatherKeyController,
            isObscured: _weatherKeyObscured,
            onToggleObscure: () => setState(() => _weatherKeyObscured = !_weatherKeyObscured),
            onSave: _saveWeatherKey,
            onTest: _testWeatherKey,
            isTesting: _testingWeather,
            isConfigured: apiKeys.hasWeatherKey,
            getKeyUrl: 'https://openweathermap.org/api',
            getKeyLabel: 'Get free API key',
          ),

          const SizedBox(height: 16),

          // World Tides Section
          _buildApiKeyCard(
            context,
            title: 'World Tides',
            subtitle: 'Tide heights, current direction and strength',
            icon: Icons.waves,
            controller: _tideKeyController,
            isObscured: _tideKeyObscured,
            onToggleObscure: () => setState(() => _tideKeyObscured = !_tideKeyObscured),
            onSave: _saveTideKey,
            onTest: _testTideKey,
            isTesting: _testingTide,
            isConfigured: apiKeys.hasTideKey,
            getKeyUrl: 'https://www.worldtides.info/developer',
            getKeyLabel: 'Get API key (free tier available)',
          ),

          const SizedBox(height: 16),

          // RapidAPI Section (for dive site search)
          _buildApiKeyCard(
            context,
            title: 'RapidAPI',
            subtitle: 'Search and import dive sites from online database',
            icon: Icons.scuba_diving,
            controller: _rapidApiKeyController,
            isObscured: _rapidApiKeyObscured,
            onToggleObscure: () => setState(() => _rapidApiKeyObscured = !_rapidApiKeyObscured),
            onSave: _saveRapidApiKey,
            onTest: _testRapidApiKey,
            isTesting: _testingRapidApi,
            isConfigured: apiKeys.hasRapidApiKey,
            getKeyUrl: 'https://rapidapi.com/the-dive-api-the-dive-api-default/api/world-scuba-diving-sites-api',
            getKeyLabel: 'Subscribe on RapidAPI',
          ),

          const SizedBox(height: 24),

          // Clear All Button
          if (apiKeys.hasAnyKey)
            OutlinedButton.icon(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Clear All API Keys?'),
                    content: const Text('This will remove all stored API keys.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await ref.read(apiKeyProvider.notifier).clearAllKeys();
                  _weatherKeyController.clear();
                  _tideKeyController.clear();
                  _rapidApiKeyController.clear();
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('All API keys cleared')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear All Keys'),
            ),
        ],
      ),
    );
  }

  Widget _buildApiKeyCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required TextEditingController controller,
    required bool isObscured,
    required VoidCallback onToggleObscure,
    required VoidCallback onSave,
    VoidCallback? onTest,
    bool isTesting = false,
    required bool isConfigured,
    required String getKeyUrl,
    required String getKeyLabel,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          if (isConfigured) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green.shade600,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: isObscured,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onTest != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isTesting ? null : onTest,
                      child: isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: onSave,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _launchUrl(getKeyUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(getKeyLabel),
            ),
          ],
        ),
      ),
    );
  }
}
