import 'package:firebase_auth/firebase_auth.dart';

// 1. Define the Interface (Service-Oriented)
// This allows us to easily mock authentication for testing later.
abstract class IAuthService {
  Stream<User?> get authStateChanges;
  Future<User?> signIn(String email, String password);
  Future<User?> register(String email, String password);
  Future<void> signOut();
  User? get currentUser;
}

// 2. The Implementation
class FirebaseAuthService implements IAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors here (e.g., user-not-found)
      throw _handleAuthException(e);
    }
  }

  @override
  Future<User?> register(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password': return 'The password provided is too weak.';
      case 'email-already-in-use': return 'The account already exists for that email.';
      case 'user-not-found': return 'No user found for that email.';
      case 'wrong-password': return 'Wrong password provided.';
      default: return 'An error occurred. Please try again.';
    }
  }
}