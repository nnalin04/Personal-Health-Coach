import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/cache/local_cache.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/app_config_storage.dart';
import '../../core/storage/token_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
final appConfigStorageProvider =
    Provider<AppConfigStorage>((ref) => AppConfigStorage());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    apiClient: ref.read(apiClientProvider),
    tokenStorage: ref.read(tokenStorageProvider),
    appConfigStorage: ref.read(appConfigStorageProvider),
  );
});

class AuthState {
  final bool initialized;
  final bool loading;
  final String? token;
  final Map<String, dynamic>? user;

  const AuthState({
    required this.initialized,
    required this.loading,
    required this.token,
    required this.user,
  });

  const AuthState.initial()
      : initialized = false,
        loading = false,
        token = null,
        user = null;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    bool? initialized,
    bool? loading,
    String? token,
    Map<String, dynamic>? user,
    bool clearToken = false,
    bool clearUser = false,
  }) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      loading: loading ?? this.loading,
      token: clearToken ? null : (token ?? this.token),
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final AppConfigStorage appConfigStorage;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '861056278474-7ir6orsre5203fbfkppff83lholn60a4.apps.googleusercontent.com',
  );

  AuthController({
    required this.apiClient,
    required this.tokenStorage,
    required this.appConfigStorage,
  }) : super(const AuthState.initial()) {
    restoreSession();
  }

  Future<void> restoreSession() async {
    final configuredBaseUrl = await appConfigStorage.readApiBaseUrl();
    if (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty) {
      apiClient.setBaseUrl(configuredBaseUrl);
    }

    final token = await tokenStorage.readToken();
    if (token != null) {
      apiClient.setAuthToken(token);
      state = state.copyWith(initialized: true, token: token);
      try {
        final response = await apiClient.get('/users/me');
        state = state.copyWith(user: Map<String, dynamic>.from(response.data));
      } catch (_) {
        await logout();
        return;
      }
      return;
    }

    state =
        state.copyWith(initialized: true, clearToken: true, clearUser: true);
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true);
    try {
      final response = await apiClient.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = Map<String, dynamic>.from(response.data);
      final token = data['accessToken'] as String;
      await tokenStorage.saveToken(token);
      apiClient.setAuthToken(token);
      state = state.copyWith(
        loading: false,
        initialized: true,
        token: token,
        user: Map<String, dynamic>.from(data['user']),
      );
    } catch (e) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(loading: true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(loading: false);
        return;
      }

      final authentication = await googleUser.authentication;
      final idToken = authentication.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google');
      }

      final response = await apiClient.post(
        '/auth/google',
        data: {'idToken': idToken},
      );

      final data = Map<String, dynamic>.from(response.data);
      final token = data['accessToken'] as String;
      await tokenStorage.saveToken(token);
      apiClient.setAuthToken(token);

      state = state.copyWith(
        loading: false,
        initialized: true,
        token: token,
        user: Map<String, dynamic>.from(data['user']),
      );
    } catch (e) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> register(Map<String, dynamic> payload) async {
    state = state.copyWith(loading: true);
    try {
      final response = await apiClient.post('/auth/register', data: payload);
      final data = Map<String, dynamic>.from(response.data);
      final token = data['accessToken'] as String;
      await tokenStorage.saveToken(token);
      apiClient.setAuthToken(token);
      state = state.copyWith(
        loading: false,
        initialized: true,
        token: token,
        user: Map<String, dynamic>.from(data['user']),
      );
    } catch (e) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> refreshUser() async {
    final response = await apiClient.get('/users/me');
    state = state.copyWith(user: Map<String, dynamic>.from(response.data));
  }

  Future<void> logout() async {
    await tokenStorage.clearToken();
    await LocalCache.clear(); // Wipe all cached data on logout
    apiClient.setAuthToken(null);
    state = state.copyWith(
      initialized: true,
      loading: false,
      clearToken: true,
      clearUser: true,
    );
  }
}
