import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveAppdataScope,
      'email',
    ],
  );
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService(ref.watch(googleSignInProvider));
});

class GoogleAuthService {
  final GoogleSignIn _googleSignIn;

  GoogleAuthService(this._googleSignIn);

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<auth.AuthClient?> getHttpClient() async {
    // This extension method provides the authenticated client
    return await _googleSignIn.authenticatedClient();
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
