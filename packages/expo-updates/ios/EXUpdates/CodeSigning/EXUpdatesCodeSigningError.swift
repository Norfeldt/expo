// Copyright 2015-present 650 Industries. All rights reserved.

import Foundation

@objc public enum EXUpdatesCodeSigningError : Int, Error {
  case CertificateParseError
  case CertificateValidityError
  case CertificateDigitalSignatureNotPresentError
  case CertificateMissingCodeSigningError
  case KeyIdMismatchError
  case SecurityFrameworkError
  case CertificateEmptyError
  case CertificateChainError
  case CertificateRootNotSelfSigned
  case SignatureHeaderMissing
  case SignatureHeaderStructuredFieldParseError
  case SignatureHeaderSigMissing
  case SignatureHeaderSignatureEncodingError
  case SignatureEncodingError
  case AlgorithmParseError
  case InvalidSignature
}

@objc public class EXUpdatesCodeSigningErrorUtils : NSObject {
  @objc public static func message(forError: EXUpdatesCodeSigningError) -> String {
    switch forError {
    case .CertificateParseError:
      return "Could not parse code signing certificate"
    case .CertificateValidityError:
      return "Certificate not valid"
    case .CertificateDigitalSignatureNotPresentError:
      return "Certificate digital signature not present"
    case .CertificateMissingCodeSigningError:
      return "Certificate missing code signing extended key usage"
    case .KeyIdMismatchError:
      return "Key with keyid from signature not found in client configuration"
    case .SecurityFrameworkError:
      return "Signature verification failed due to security framework error"
    case .CertificateEmptyError:
      return "No code signing certificates provided"
    case .CertificateChainError:
      return "Certificate chain error"
    case .CertificateRootNotSelfSigned:
      return "Root certificate not self-signed"
    case .SignatureHeaderMissing:
      return "No expo-signature header specified"
    case .SignatureHeaderStructuredFieldParseError:
      return "expo-signature structured header parsing failed"
    case .SignatureHeaderSigMissing:
      return "Structured field sig not found in expo-signature header"
    case .SignatureHeaderSignatureEncodingError:
      return "Signature in header has invalid encoding"
    case .SignatureEncodingError:
      return "Invalid signatre encoding"
    case .AlgorithmParseError:
      return "Invalid algorithm"
    case .InvalidSignature:
      return "Manifest download was successful, but signature was incorrect"
    }
  }
}
