import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _kLogged = 'mrs_logged';
  static const _kUsId = 'mrs_usId';

  static const _kUsNombre = 'mrs_usNombre';
  static const _kUsAPaterno = 'mrs_usAPaterno';
  static const _kUsAMaterno = 'mrs_usAMaterno';
  static const _kUsCorreo = 'mrs_usCorreo';
  static const _kUsTelefono = 'mrs_usTelefono';
  static const _kUsUsername = 'mrs_usUsername';
  static const _kUsImagen = 'mrs_usImagen';

  // RBAC
  static const _kUcrRol = 'mrs_ucrRol';
  static const _kCzId = 'mrs_czId';
  static const _kCsId = 'mrs_csId';
  static const _kUcrClId = 'mrs_ucrClId';

  static Future<void> saveLogin({
    required String usId,
    required String userName,
    String usAPaterno = '',
    String usAMaterno = '',
    String usCorreo = '',
    String usTelefono = '',
    String usUsername = '',
    String? usImagen,
    String ucrRol = '',
    int? czId,
    int? csId,
    int? ucrClId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLogged, true);
    await sp.setString(_kUsId, usId);

    await sp.setString(_kUsNombre, userName);
    await sp.setString(_kUsAPaterno, usAPaterno);
    await sp.setString(_kUsAMaterno, usAMaterno);
    await sp.setString(_kUsCorreo, usCorreo);
    await sp.setString(_kUsTelefono, usTelefono);
    await sp.setString(_kUsUsername, usUsername);
    if (usImagen != null) await sp.setString(_kUsImagen, usImagen);

    await sp.setString(_kUcrRol, ucrRol);
    if (czId != null) await sp.setInt(_kCzId, czId);
    if (csId != null) await sp.setInt(_kCsId, csId);
    if (ucrClId != null) await sp.setInt(_kUcrClId, ucrClId);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final sp = await SharedPreferences.getInstance();
    return {
      'logged': sp.getBool(_kLogged) ?? false,
      'usId': sp.getString(_kUsId),
      'usNombre': sp.getString(_kUsNombre),
      'usAPaterno': sp.getString(_kUsAPaterno),
      'usAMaterno': sp.getString(_kUsAMaterno),
      'usCorreo': sp.getString(_kUsCorreo),
      'usTelefono': sp.getString(_kUsTelefono),
      'usUsername': sp.getString(_kUsUsername),
      'usImagen': sp.getString(_kUsImagen),
      'ucrRol': sp.getString(_kUcrRol),
      'czId': sp.getInt(_kCzId),
      'csId': sp.getInt(_kCsId),
      'ucrClId': sp.getInt(_kUcrClId),
    };
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  }

  Future<void> debugDump({String tag = 'SessionStore'}) async {
    final sp = await SharedPreferences.getInstance();
    print('[$tag] logged=${sp.getBool(_kLogged) ?? false}');
    print('[$tag] usId=${sp.getString(_kUsId)}');
    print('[$tag] usNombre=${sp.getString(_kUsNombre)}');
    print('[$tag] usAPaterno=${sp.getString(_kUsAPaterno)}');
    print('[$tag] usAMaterno=${sp.getString(_kUsAMaterno)}');
    print('[$tag] usCorreo=${sp.getString(_kUsCorreo)}');
    print('[$tag] usTelefono=${sp.getString(_kUsTelefono)}');
    print('[$tag] usUsername=${sp.getString(_kUsUsername)}');
    print('[$tag] usImagen=${sp.getString(_kUsImagen)}');
    print('[$tag] ucrRol=${sp.getString(_kUcrRol)}');
    print('[$tag] czId=${sp.getInt(_kCzId)}');
    print('[$tag] csId=${sp.getInt(_kCsId)}');
    print('[$tag] ucrClId=${sp.getInt(_kUcrClId)}');
  }

  static Future<String> ucrRol() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kUcrRol) ?? '';
  }

  static Future<int?> czId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kCzId);
  }

  static Future<int?> csId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kCsId);
  }

  static Future<int?> ucrClId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kUcrClId);
  }

  static Future<bool> isLogged() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLogged) ?? false;
  }

  static Future<String?> usId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kUsId);
  }

  static Future<String?> userName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kUsUsername);
  }
}
