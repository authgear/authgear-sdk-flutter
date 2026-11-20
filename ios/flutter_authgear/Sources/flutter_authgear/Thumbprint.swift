import CommonCrypto
import Foundation

// Reference: https://github.com/airsidemobile/JOSESwift/blob/master/JOSESwift/Sources/CryptoImplementation/Thumbprint.swift#L47

enum JWKThumbprintAlgorithm: String {
    case SHA256
}

private extension JWKThumbprintAlgorithm {
    var outputLenght: Int {
        switch self {
        case .SHA256:
            return Int(CC_SHA256_DIGEST_LENGTH)
        }
    }

    func calculate(input: UnsafeRawBufferPointer, output: UnsafeMutablePointer<UInt8>) {
        switch self {
        case .SHA256:
            CC_SHA256(input.baseAddress, CC_LONG(input.count), output)
        }
    }
}

enum Thumbprint {
    /// Calculates a hash of an input with a specific hash algorithm.
    ///
    /// - Parameters:
    ///   - input: The input to calculate a hash for.
    ///   - algorithm: The algorithm used to calculate the hash.
    /// - Returns: The calculated hash in base64URLEncoding.
    static func calculate(from input: Data, algorithm: JWKThumbprintAlgorithm) throws -> String {
        guard !input.isEmpty else {
            throw AuthgearError.runtimeError(AuthgearRuntimeError(message: "input must be > 0"))
        }

        let hashBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: algorithm.outputLenght)
        defer { hashBytes.deallocate() }

        input.withUnsafeBytes { buffer in
            algorithm.calculate(input: buffer, output: hashBytes)
        }

        return Data(bytes: hashBytes, count: algorithm.outputLenght).base64urlEncodedString()
    }
}
