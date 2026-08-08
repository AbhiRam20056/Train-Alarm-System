import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Phone OTP flow ──────────────────────────────────────────────────────────

  Future<void> verifyPhone({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onAutoVerified,
    required void Function(FirebaseAuthException) onFailed,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String verificationId) onTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) =>
      _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        verificationCompleted: onAutoVerified,
        verificationFailed: onFailed,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: onTimeout,
      );

  Future<UserCredential> signInWithOtp(
      String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(result.user!);
    return result;
  }

  Future<void> signOut() => _auth.signOut();

  // ── Firestore user doc ───────────────────────────────────────────────────────

  Future<void> _ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'phone': user.phoneNumber,
        'displayName': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'favouriteStations': <String>[],
      });
    }
  }
}
