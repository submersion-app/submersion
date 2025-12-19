import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for secure storage of API credentials.
class ApiKeyConstants {
  static const String openWeatherMapKey = 'openweathermap_api_key';
  static const String worldTidesKey = 'worldtides_api_key';
}

/// Secure storage provider.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

/// State for API keys.
class ApiKeyState {
  final String? openWeatherMapKey;
  final String? worldTidesKey;
  final bool isLoading;

  const ApiKeyState({
    this.openWeatherMapKey,
    this.worldTidesKey,
    this.isLoading = false,
  });

  bool get hasWeatherKey => openWeatherMapKey?.isNotEmpty == true;
  bool get hasTideKey => worldTidesKey?.isNotEmpty == true;
  bool get hasAnyKey => hasWeatherKey || hasTideKey;

  ApiKeyState copyWith({
    String? openWeatherMapKey,
    String? worldTidesKey,
    bool? isLoading,
  }) {
    return ApiKeyState(
      openWeatherMapKey: openWeatherMapKey ?? this.openWeatherMapKey,
      worldTidesKey: worldTidesKey ?? this.worldTidesKey,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// StateNotifier for managing API keys with secure storage.
class ApiKeyNotifier extends StateNotifier<ApiKeyState> {
  final FlutterSecureStorage _storage;

  ApiKeyNotifier(this._storage) : super(const ApiKeyState(isLoading: true)) {
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final weatherKey = await _storage.read(key: ApiKeyConstants.openWeatherMapKey);
      final tideKey = await _storage.read(key: ApiKeyConstants.worldTidesKey);

      state = ApiKeyState(
        openWeatherMapKey: weatherKey,
        worldTidesKey: tideKey,
        isLoading: false,
      );
    } catch (e) {
      // If secure storage fails, continue with empty keys
      state = const ApiKeyState(isLoading: false);
    }
  }

  Future<void> setOpenWeatherMapKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: ApiKeyConstants.openWeatherMapKey);
      state = state.copyWith(openWeatherMapKey: null);
    } else {
      await _storage.write(key: ApiKeyConstants.openWeatherMapKey, value: key);
      state = state.copyWith(openWeatherMapKey: key);
    }
  }

  Future<void> setWorldTidesKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: ApiKeyConstants.worldTidesKey);
      state = state.copyWith(worldTidesKey: null);
    } else {
      await _storage.write(key: ApiKeyConstants.worldTidesKey, value: key);
      state = state.copyWith(worldTidesKey: key);
    }
  }

  Future<void> clearAllKeys() async {
    await _storage.delete(key: ApiKeyConstants.openWeatherMapKey);
    await _storage.delete(key: ApiKeyConstants.worldTidesKey);
    state = const ApiKeyState(isLoading: false);
  }
}

/// Provider for API key state.
final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, ApiKeyState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiKeyNotifier(storage);
});

/// Convenience provider for checking if weather API is configured.
final hasWeatherApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(apiKeyProvider.select((s) => s.hasWeatherKey));
});

/// Convenience provider for checking if tide API is configured.
final hasTideApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(apiKeyProvider.select((s) => s.hasTideKey));
});
