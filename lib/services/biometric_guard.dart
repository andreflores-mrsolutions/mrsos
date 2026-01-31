import 'package:local_auth/local_auth.dart';

class BiometricGuard {
  static final _auth = LocalAuthentication();

  static Future<bool> canUseBiometrics() async {
    try {
      final can = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return can && supported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> unlock({String reason = 'Confirma tu identidad'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly:
              false, // permite PIN/patrón del sistema si no hay biométrico
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
