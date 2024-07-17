import 'native.dart' as native;

abstract class TokenStorage {
  Future<void> setRefreshToken(String namespace, String token);
  Future<String?> getRefreshToken(String namespace);
  Future<void> delRefreshToken(String namespace);
}

abstract class InterAppSharedStorage {
  Future<void> setIDToken(String namespace, String token);
  Future<String?> getIDToken(String namespace);
  Future<void> delIDToken(String namespace);

  Future<void> setDeviceSecret(String namespace, String deviceSecret);
  Future<String?> getDeviceSecret(String namespace);
  Future<void> delDeviceSecret(String namespace);

  Future<void> setDPoPKeyID(String namespace, String kidD);
  Future<String?> getDPoPKeyID(String namespace);
  Future<void> delDPoPKeyID(String namespace);

  Future<void> onLogout(String namespace);
}

abstract class ContainerStorage {
  Future<void> setAnonymousKeyID(String namespace, String kid);
  Future<String?> getAnonymousKeyID(String namespace);
  Future<void> delAnonymousKeyID(String namespace);

  Future<void> setBiometricKeyID(String namespace, String kid);
  Future<String?> getBiometricKeyID(String namespace);
  Future<void> delBiometricKeyID(String namespace);
}

abstract class _StorageDriver {
  Future<void> set(String key, String value);
  Future<String?> get(String key);
  Future<void> del(String key);
}

class _KeyMaker {
  String scopedKey(String key) {
    return "authgear_$key";
  }

  String keyRefreshToken(String namespace) {
    return scopedKey("${namespace}_refreshToken");
  }

  String keyIDToken(String namespace) {
    return scopedKey("${namespace}_idToken");
  }

  String keyDeviceSecret(String namespace) {
    return scopedKey("${namespace}_deviceSecret");
  }

  String keyAnonymousKeyID(String namespace) {
    return scopedKey("${namespace}_anonymousKeyID");
  }

  String keyBiometricKeyID(String namespace) {
    return scopedKey("${namespace}_biometricKeyID");
  }

  String keyDPoPKeyID(String namespace) {
    return scopedKey("${namespace}_dpopKeyID");
  }
}

class _MemoryStorageDriver implements _StorageDriver {
  final Map<String, String> _backingStorage = {};

  @override
  Future<void> set(String key, String value) async {
    _backingStorage[key] = value;
  }

  @override
  Future<String?> get(String key) async {
    return _backingStorage[key];
  }

  @override
  Future<void> del(String key) async {
    _backingStorage.remove(key);
  }
}

class _PlatformStorageDriver implements _StorageDriver {
  @override
  Future<void> set(String key, String value) async {
    await native.storageSetItem(key, value);
  }

  @override
  Future<String?> get(String key) async {
    return await native.storageGetItem(key);
  }

  @override
  Future<void> del(String key) async {
    await native.storageDeleteItem(key);
  }
}

abstract class AbstractTokenStorage implements TokenStorage {
  abstract final _StorageDriver _driver;
  abstract final _KeyMaker _keyMaker;

  @override
  Future<void> setRefreshToken(String namespace, String token) async {
    final key = _keyMaker.keyRefreshToken(namespace);
    _driver.set(key, token);
  }

  @override
  Future<String?> getRefreshToken(String namespace) async {
    final key = _keyMaker.keyRefreshToken(namespace);
    return _driver.get(key);
  }

  @override
  Future<void> delRefreshToken(String namespace) async {
    final key = _keyMaker.keyRefreshToken(namespace);
    _driver.del(key);
  }
}

class TransientTokenStorage extends AbstractTokenStorage {
  @override
  final _StorageDriver _driver;
  @override
  final _KeyMaker _keyMaker;

  TransientTokenStorage()
      : _driver = _MemoryStorageDriver(),
        _keyMaker = _KeyMaker();
}

class PersistentTokenStorage extends AbstractTokenStorage {
  @override
  final _StorageDriver _driver;
  @override
  final _KeyMaker _keyMaker;

  PersistentTokenStorage()
      : _driver = _PlatformStorageDriver(),
        _keyMaker = _KeyMaker();
}

class PersistentInterAppSharedStorage extends InterAppSharedStorage {
  final _StorageDriver _driver;
  final _KeyMaker _keyMaker;

  PersistentInterAppSharedStorage()
      : _driver = _PlatformStorageDriver(),
        _keyMaker = _KeyMaker();

  @override
  Future<void> setDeviceSecret(String namespace, String deviceSecret) {
    return _driver.set(_keyMaker.keyDeviceSecret(namespace), deviceSecret);
  }

  @override
  Future<String?> getDeviceSecret(String namespace) {
    return _driver.get(_keyMaker.keyDeviceSecret(namespace));
  }

  @override
  Future<void> delDeviceSecret(String namespace) {
    return _driver.del(_keyMaker.keyDeviceSecret(namespace));
  }

  @override
  Future<void> setIDToken(String namespace, String token) {
    return _driver.set(_keyMaker.keyIDToken(namespace), token);
  }

  @override
  Future<String?> getIDToken(String namespace) {
    return _driver.get(_keyMaker.keyIDToken(namespace));
  }

  @override
  Future<void> delIDToken(String namespace) {
    return _driver.del(_keyMaker.keyIDToken(namespace));
  }

  Future<void> setDPoPKeyID(String namespace, String kid) {
    return _driver.set(_keyMaker.keyDPoPKeyID(namespace), kid);
  }

  @override
  Future<String?> getDPoPKeyID(String namespace) {
    return _driver.get(_keyMaker.keyDPoPKeyID(namespace));
  }

  @override
  Future<void> delDPoPKeyID(String namespace) {
    return _driver.del(_keyMaker.keyDPoPKeyID(namespace));
  }

  @override
  Future<void> onLogout(String namespace) async {
    await delDeviceSecret(namespace);
    await delIDToken(namespace);
    await delDPoPKeyID(namespace);
  }
}

class PersistentContainerStorage implements ContainerStorage {
  final _StorageDriver _driver;
  final _KeyMaker _keyMaker;

  PersistentContainerStorage()
      : _driver = _PlatformStorageDriver(),
        _keyMaker = _KeyMaker();

  @override
  Future<void> setBiometricKeyID(String namespace, String token) async {
    final key = _keyMaker.keyBiometricKeyID(namespace);
    _driver.set(key, token);
  }

  @override
  Future<String?> getBiometricKeyID(String namespace) async {
    final key = _keyMaker.keyBiometricKeyID(namespace);
    return _driver.get(key);
  }

  @override
  Future<void> delBiometricKeyID(String namespace) async {
    final key = _keyMaker.keyBiometricKeyID(namespace);
    _driver.del(key);
  }

  @override
  Future<void> setAnonymousKeyID(String namespace, String token) async {
    final key = _keyMaker.keyAnonymousKeyID(namespace);
    _driver.set(key, token);
  }

  @override
  Future<String?> getAnonymousKeyID(String namespace) async {
    final key = _keyMaker.keyAnonymousKeyID(namespace);
    return _driver.get(key);
  }

  @override
  Future<void> delAnonymousKeyID(String namespace) async {
    final key = _keyMaker.keyAnonymousKeyID(namespace);
    _driver.del(key);
  }
}
