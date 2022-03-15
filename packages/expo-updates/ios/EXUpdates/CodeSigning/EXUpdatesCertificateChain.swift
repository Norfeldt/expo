// Copyright 2015-present 650 Industries. All rights reserved.

import Foundation
import ASN1Decoder

typealias Certificate = (SecCertificate, X509Certificate)

/**
 * Full certificate chain for verifying code signing.
 * The chain should look like the following:
 *    0: code signing certificate
 *    1...n-1: intermediate certificates
 *    n: root certificate
 *
 * Requirements:
 * - Length(certificateChain) > 0
 * - certificate chain is valid and each certificate is valid
 * - 0th certificate is a valid code signing certificate
 */
class EXUpdatesCertificateChain {
  // ASN.1 path to the extended key usage info within a CERT
  static let EXUpdatesCodeSigningCertificateExtendedUsageCodeSigningOID = "1.3.6.1.5.5.7.3.3"
  
  private var certificateStrings: [String]
  
  public required init(certificateStrings: [String]) throws {
    self.certificateStrings = certificateStrings
  }
  
  public func codeSigningCertificate() throws -> Certificate {
    if (certificateStrings.isEmpty) {
      throw EXUpdatesCodeSigningError.CertificateEmptyError
    }
    
    let certificateChain = try certificateStrings.map { certificateString throws in
      try EXUpdatesCertificateChain.constructCertificate(certificateString: certificateString)
    }
    try certificateChain.validateChain()
    
    let leafCertificate = certificateChain.first!
    let (_, x509lLeafCertificate) = leafCertificate
    if (!x509lLeafCertificate.isCodeSigningCertificate()) {
      throw EXUpdatesCodeSigningError.CertificateMissingCodeSigningError
    }
    
    return leafCertificate
  }
  
  private static func constructCertificate(certificateString: String) throws -> Certificate {
    guard let certificateData = certificateString.data(using: .utf8) else { throw EXUpdatesCodeSigningError.CertificateParseError }
    
    guard let certificateDataDer = decodeToDER(pem: certificateData) else {
      throw EXUpdatesCodeSigningError.CertificateParseError
    }
    
    let x509Certificate = try X509Certificate(der: certificateDataDer)
    
    guard x509Certificate.checkValidity() else {
      throw EXUpdatesCodeSigningError.CertificateValidityError
    }
    
    guard let secCertificate = SecCertificateCreateWithData(nil, certificateDataDer as CFData) else {
      throw EXUpdatesCodeSigningError.CertificateParseError
    }
    
    return (secCertificate, x509Certificate)
  }
  
  private static let beginPemBlock = "-----BEGIN CERTIFICATE-----"
  private static let endPemBlock   = "-----END CERTIFICATE-----"
  
  /**
   * Mostly from ASN1Decoder with the fix for disallowing multiple certificatess in the PEM.
   */
  private static func decodeToDER(pem pemData: Data) -> Data? {
    guard let pem = String(data: pemData, encoding: .ascii) else {
      return nil
    }
    
    if pem.components(separatedBy: beginPemBlock).count - 1 != 1 {
      return nil
    }
    
    let lines = pem.components(separatedBy: .newlines)
    var base64buffer  = ""
    var certLine = false
    for line in lines {
      if line == endPemBlock {
        certLine = false
      }
      if certLine {
        base64buffer.append(line)
      }
      if line == beginPemBlock {
        certLine = true
      }
    }
    if let derDataDecoded = Data(base64Encoded: base64buffer) {
      return derDataDecoded
    }
    
    return nil
  }
}

extension X509Certificate {
  func isCACertificate() -> Bool {
    if let ext = self.extensionObject(oid: .basicConstraints) as? X509Certificate.BasicConstraintExtension {
      if (!ext.isCA) {
        return false
      }
    } else {
      return false
    }
    
    let keyUsage = self.keyUsage
    if (keyUsage.isEmpty || !keyUsage[5]) {
      return false
    }
    
    return true
  }
  
  func isCodeSigningCertificate() -> Bool {
    let keyUsage = self.keyUsage
    if (keyUsage.isEmpty || !keyUsage[0]) {
      return false
    }
    
    let extendedKeyUsage = self.extendedKeyUsage
    if (!extendedKeyUsage.contains(EXUpdatesCertificateChain.EXUpdatesCodeSigningCertificateExtendedUsageCodeSigningOID)) {
      return false
    }
    
    return true
  }
}

extension Array where Element == Certificate {
  func validateChain() throws {
    let (anchorSecCert, anchorX509Cert) = self.last!
    
    // only trust anchor if self-signed
    if (anchorX509Cert.subjectDistinguishedName != anchorX509Cert.issuerDistinguishedName) {
      throw EXUpdatesCodeSigningError.CertificateRootNotSelfSigned
    }
    
    let secCertificates = self.map { (secCertificate, _) in
      secCertificate
    }
    let trust = try SecTrust.create(certificates: secCertificates, policy: SecPolicyCreateBasicX509())
    try trust.setAnchorCertificates([anchorSecCert])
    try trust.disableNetwork()
    try trust.evaluate()
  }
}

extension SecTrust {
  static func create(certificates: [SecCertificate], policy: SecPolicy) throws -> SecTrust {
    var optionalTrust: SecTrust?
    let status = SecTrustCreateWithCertificates(certificates as AnyObject, policy, &optionalTrust)
    guard let trust = optionalTrust, status.isSuccess else {
      throw EXUpdatesCodeSigningError.CertificateChainError
    }
    return trust
  }
  
  func setAnchorCertificates(_ anchorCertificates: [SecCertificate]) throws {
    let status = SecTrustSetAnchorCertificates(self, anchorCertificates as CFArray)
    guard status.isSuccess else {
      throw EXUpdatesCodeSigningError.CertificateChainError
    }

    let status2 = SecTrustSetAnchorCertificatesOnly(self, true)
    guard status2.isSuccess else {
      throw EXUpdatesCodeSigningError.CertificateChainError
    }
  }
  
  func disableNetwork() throws {
    let status = SecTrustSetNetworkFetchAllowed(self, false)
    guard status.isSuccess else {
      throw EXUpdatesCodeSigningError.CertificateChainError
    }
  }
  
  func evaluate() throws {
    var error: CFError?
    let success = SecTrustEvaluateWithError(self, &error)
    if !success {
      throw EXUpdatesCodeSigningError.CertificateChainError
    }
  }
}
