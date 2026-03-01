import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Keys for secure storage
  static const String _refreshTokenKey = 'pigio_refresh_token';

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> initialize() async {
    // Supabase handles token refresh automatically if we use its built-in session management.
    // We can still store the refresh token securely if needed for custom flows.
  }

  Future<void> signInWithEmail(String email) async {
    // Magic link / OTP flow
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
  }

  Future<AuthResponse> verifyOTP(String email, String token) async {
    final response = await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email, // email = 6-digit code entered manually; magiclink = URL token
    );
    
    if (response.session != null) {
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: response.session!.refreshToken,
      );
    }
    return response;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}
