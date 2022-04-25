abstract class TokenStorage {
  Future<void> setRefreshToken(String namespace, String token);
  Future<String?> getRefreshToken(String namespace);
  Future<void> delRefreshToken(String namespace);
}

abstract class _ContainerStorage {
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
    return "authgear_${key}";
  }

  String keyRefreshToken(String namespace) {
    return scopedKey("${namespace}_refreshToken");
  }

  String keyAnonymousKeyID(String namespace) {
    return scopedKey("${namespace}_anonymousKeyID");
  }

  String keyBiometricID(String namespace) {
    return scopedKey("${namespace}_biometricKeyID");
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

class TransientTokenStorage implements TokenStorage {
  final _StorageDriver _driver = _MemoryStorageDriver();
  final _KeyMaker _keyMaker = _KeyMaker();

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
