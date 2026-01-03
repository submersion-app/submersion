import 'package:submersion/core/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for storage of API credentials.
class ApiKeyConstants {
  static const String openWeatherMapKey = 'openweathermap_api_key';
  static const String worldTidesKey = 'worldtides_api_key';
  static const String rapidApiKey = 'rapidapi_api_key';
}

/// State for API keys.
class ApiKeyState {
  final String? openWeatherMapKey;
  final String? worldTidesKey;
  final String? rapidApiKey;
  final bool isLoading;

  const ApiKeyState({
    this.openWeatherMapKey,
    this.worldTidesKey,
    this.rapidApiKey,
    this.isLoading = false,
  });

  bool get hasWeatherKey => openWeatherMapKey?.isNotEmpty == true;
  bool get hasTideKey => worldTidesKey?.isNotEmpty == true;
  bool get hasRapidApiKey => rapidApiKey?.isNotEmpty == true;
  bool get hasAnyKey => hasWeatherKey || hasTideKey || hasRapidApiKey;
}

/// StateNotifier for managing API keys with SharedPreferences.
class ApiKeyNotifier extends StateNotifier<ApiKeyState> {
  ApiKeyNotifier() : super(const ApiKeyState(isLoading: true)) {
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weatherKey = prefs.getString(ApiKeyConstants.openWeatherMapKey);
      final tideKey = prefs.getString(ApiKeyConstants.worldTidesKey);
      final rapidKey = prefs.getString(ApiKeyConstants.rapidApiKey);

      state = ApiKeyState(
        openWeatherMapKey: weatherKey,
        worldTidesKey: tideKey,
        rapidApiKey: rapidKey,
        isLoading: false,
      );
    } catch (e) {
      // If storage fails, continue with empty keys
      state = const ApiKeyState(isLoading: false);
    }
  }

  Future<(bool, String?)> setOpenWeatherMapKey(String? key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key == null || key.isEmpty) {
        await prefs.remove(ApiKeyConstants.openWeatherMapKey);
        state = ApiKeyState(
          openWeatherMapKey: null,
          worldTidesKey: state.worldTidesKey,
          rapidApiKey: state.rapidApiKey,
          isLoading: false,
        );
      } else {
        await prefs.setString(ApiKeyConstants.openWeatherMapKey, key);
        state = ApiKeyState(
          openWeatherMapKey: key,
          worldTidesKey: state.worldTidesKey,
          rapidApiKey: state.rapidApiKey,
          isLoading: false,
        );
      }
      return (true, null);
    } catch (e) {
      return (false, 'Failed to save: $e');
    }
  }

  Future<(bool, String?)> setWorldTidesKey(String? key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key == null || key.isEmpty) {
        await prefs.remove(ApiKeyConstants.worldTidesKey);
        state = ApiKeyState(
          openWeatherMapKey: state.openWeatherMapKey,
          worldTidesKey: null,
          rapidApiKey: state.rapidApiKey,
          isLoading: false,
        );
      } else {
        await prefs.setString(ApiKeyConstants.worldTidesKey, key);
        state = ApiKeyState(
          openWeatherMapKey: state.openWeatherMapKey,
          worldTidesKey: key,
          rapidApiKey: state.rapidApiKey,
          isLoading: false,
        );
      }
      return (true, null);
    } catch (e) {
      return (false, 'Failed to save: $e');
    }
  }

  Future<(bool, String?)> setRapidApiKey(String? key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key == null || key.isEmpty) {
        await prefs.remove(ApiKeyConstants.rapidApiKey);
        state = ApiKeyState(
          openWeatherMapKey: state.openWeatherMapKey,
          worldTidesKey: state.worldTidesKey,
          rapidApiKey: null,
          isLoading: false,
        );
      } else {
        await prefs.setString(ApiKeyConstants.rapidApiKey, key);
        state = ApiKeyState(
          openWeatherMapKey: state.openWeatherMapKey,
          worldTidesKey: state.worldTidesKey,
          rapidApiKey: key,
          isLoading: false,
        );
      }
      return (true, null);
    } catch (e) {
      return (false, 'Failed to save: $e');
    }
  }

  Future<void> clearAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiKeyConstants.openWeatherMapKey);
    await prefs.remove(ApiKeyConstants.worldTidesKey);
    await prefs.remove(ApiKeyConstants.rapidApiKey);
    state = const ApiKeyState(isLoading: false);
  }
}

/// Provider for API key state.
final apiKeyProvider =
    StateNotifierProvider<ApiKeyNotifier, ApiKeyState>((ref) {
  return ApiKeyNotifier();
});

/// Convenience provider for checking if weather API is configured.
final hasWeatherApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(apiKeyProvider.select((s) => s.hasWeatherKey));
});

/// Convenience provider for checking if tide API is configured.
final hasTideApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(apiKeyProvider.select((s) => s.hasTideKey));
});

/// Convenience provider for checking if RapidAPI is configured.
final hasRapidApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(apiKeyProvider.select((s) => s.hasRapidApiKey));
});

/// Convenience provider for getting the RapidAPI key.
final rapidApiKeyProvider = Provider<String?>((ref) {
  return ref.watch(apiKeyProvider.select((s) => s.rapidApiKey));
});
