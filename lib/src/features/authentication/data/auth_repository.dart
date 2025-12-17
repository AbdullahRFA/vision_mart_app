import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 1. Provider for the Service
// If we switch to a different backend later, we only change this line.
final authServiceProvider = Provider<IAuthService>((ref) {
  return FirebaseAuthService();
});

// 2. Stream Provider for Auth State
// This allows the UI to react instantly when a user logs in or out.
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});