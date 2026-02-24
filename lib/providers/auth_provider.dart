import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// AuthService provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Current user stream provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Current user profile provider
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return UserProfileNotifier(authService);
});

class UserProfileNotifier extends StateNotifier<UserModel?> {
  final AuthService _authService;

  UserProfileNotifier(this._authService) : super(null) {
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await _authService.getUserProfile(user.uid);
      state = profile;
    }
  }

  Future<void> updateProfile(UserModel user) async {
    await _authService.updateUserProfile(user);
    state = user;
  }

  Future<void> refreshProfile() async {
    await _loadUserProfile();
  }

  Future<void> logout() async {
    await _authService.logout();
    state = null;
  }
}
