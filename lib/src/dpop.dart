import 'storage.dart';
import 'native.dart' as native;

abstract class DPoPProvider {
  Future<String> generateDPoPProof({required String htm, required String htu});
  Future<String> computeJKT();
}

class DefaultDPoPProvider implements DPoPProvider {
  final String namespace;
  final InterAppSharedStorage sharedStorage;

  DefaultDPoPProvider({
    required this.namespace,
    required this.sharedStorage,
  });

  @override
  Future<String> generateDPoPProof({
    required String htm,
    required String htu,
  }) async {
    final existingKeyId = await sharedStorage.getDPoPKeyID(namespace);
    String kid;
    if (existingKeyId != null) {
      kid = existingKeyId;
    } else {
      kid = await native.generateUUID();
      await native.createDPoPPrivateKey(kid: kid);
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    final payload = {
      "iat": now,
      "exp": now + 300,
      "jti": await native.generateUUID(),
      "htm": htm,
      "htu": htu,
    };
    try {
      return await native.signWithDPoPPrivateKey(
        kid: kid,
        payload: payload,
      );
    } catch (e) {
      // Generate a new key if the original key cannot be used for any reason
      kid = await native.generateUUID();
      await native.createDPoPPrivateKey(kid: kid);
      return await native.signWithDPoPPrivateKey(
        kid: kid,
        payload: payload,
      );
    }
  }

  @override
  Future<String> computeJKT() {
    // TODO: implement computeJKT
    throw UnimplementedError();
  }
}
