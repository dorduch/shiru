import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.providerIds,
  });

  final String uid;
  final String? email;
  final List<String> providerIds;
}

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<void> createWithEmail(String email, String password);
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
  Future<void> deleteCurrentUser();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  Future<void>? _googleInitialization;

  AuthUser? _map(User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          email: user.email,
          providerIds: user.providerData
              .map((data) => data.providerId)
              .toList(),
        );

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> createWithEmail(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    _googleInitialization ??= GoogleSignIn.instance.initialize();
    await _googleInitialization;
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    await _auth.signInWithProvider(provider);
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      _googleInitialization ??= GoogleSignIn.instance.initialize();
      await _googleInitialization;
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Firebase sign-out is authoritative. Google cleanup is best effort.
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
  }
}
