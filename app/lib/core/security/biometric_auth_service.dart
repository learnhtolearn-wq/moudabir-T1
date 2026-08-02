import 'package:local_auth/local_auth.dart';

/// Wraps device biometrics (fingerprint/face) as the second local factor,
/// alongside the app PIN. No server round-trip — this is what "2FA"
/// means in Moudabbir: two local factors, zero cloud dependency.
class BiometricAuthService {
  BiometricAuthService(this._auth);

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  }

  Future<bool> authenticate({String reason = 'auth_reason'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
