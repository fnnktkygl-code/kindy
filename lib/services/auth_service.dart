import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Keys for secure storage
  static const String _biometricRefreshKey = 'pigio_biometric_refresh';

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> signInWithEmail(String email) async {
    // Magic link / OTP flow
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
  }

  Future<void> sendOtpForExistingAccount(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
  }

  /// Send a password reset link to the user's email.
  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'pigio://auth/callback',
    );
  }

  Future<AuthResponse> signUpWithEmailPassword(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'pigio://auth/callback',
    );
    return response;
  }

  Future<AuthResponse> signInWithPassword(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  // ── Biometric credential storage (refresh-token based) ──────────────

  /// Save the current session's refresh token for biometric re-auth.
  /// Called after a successful login when the user has opted into biometrics.
  Future<void> saveBiometricCredentials(String email, String password) async {
    // Store refresh token instead of password for better security.
    final session = _supabase.auth.currentSession;
    final refreshToken = session?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _biometricRefreshKey, value: refreshToken);
    }
  }

  Future<void> clearBiometricCredentials() async {
    await _secureStorage.delete(key: _biometricRefreshKey);
  }

  Future<bool> hasBiometricCredentials() async {
    final token = await _secureStorage.read(key: _biometricRefreshKey);
    return token != null && token.isNotEmpty;
  }

  /// Sign in using a stored refresh token (biometric flow).
  /// Returns the new session or throws if the token is expired/invalid.
  Future<AuthResponse> signInWithBiometricToken() async {
    final refreshToken = await _secureStorage.read(key: _biometricRefreshKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('Aucun identifiant biométrique sauvegardé');
    }

    final response = await _supabase.auth.setSession(refreshToken);

    // Store the new refresh token so it stays fresh
    final newRefresh = response.session?.refreshToken;
    if (newRefresh != null && newRefresh.isNotEmpty) {
      await _secureStorage.write(key: _biometricRefreshKey, value: newRefresh);
    }

    return response;
  }

  Future<AuthResponse> verifyOTP(String email, String token) async {
    final response = await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    return response;
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await clearBiometricCredentials();
  }
}
