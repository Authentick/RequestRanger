import Foundation
import X509
import CryptoKit
import SwiftASN1
import Security

class CertificateManager {
    static let shared = CertificateManager()
    private init() {}
    private var certificates: [String: (certificate: Certificate, privateKey: P256.Signing.PrivateKey)] = [:]
    private let queue = DispatchQueue(label: "net.authentick.RequestRanger.CertificateManager")
    
    func createRootCA() throws {
        let rootCACertificate = try generateSelfSignedCertificate(hostName: "Root CA")
        saveToKeychain(privateKey: rootCACertificate.key)
        saveCertificateToKeychain(certificate: rootCACertificate.certificate, withLabel: "RootCACertificate")
        self.certificates = [:]
    }
    
    func createCertificateForDomain(_ domain: String) throws {
        let rootCAKey = try loadRootCAFromKeychain()
        let certificate = try generateCertificateForDomain(domain, signedBy: rootCAKey.rootPrivateKey)
        queue.sync {
            certificates[domain] = (certificate: certificate.certificate, privateKey: certificate.key)
        }
    }
    
    func certificateForDomain(_ domain: String) -> (certificate: Certificate, privateKey: P256.Signing.PrivateKey)? {
        var discoveredCertificate: (certificate: Certificate, privateKey: P256.Signing.PrivateKey)?
        
        queue.sync {
            discoveredCertificate = certificates[domain]
        }
        
        if discoveredCertificate == nil {
            try! createCertificateForDomain(domain)
            return certificateForDomain(domain)
        }
        
        return discoveredCertificate
    }
    
    private func generateCertificate(hostName: String, issuerPrivateKey: P256.Signing.PrivateKey? = nil) throws -> (certificate: Certificate, key: P256.Signing.PrivateKey) {
        let swiftCryptoKey = P256.Signing.PrivateKey()
        let key = Certificate.PrivateKey(swiftCryptoKey)
        
        let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String
        let subjectName = try DistinguishedName { CommonName(appName) }
        let issuerName =  subjectName
        let now = Date()
        
        var extensions: Certificate.Extensions
        if(issuerPrivateKey == nil) {
            extensions = try Certificate.Extensions {
                Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
                Critical(KeyUsage(digitalSignature: true, keyCertSign: true, cRLSign: true))
            }        } else {
                extensions = try Certificate.Extensions {
                    Critical(BasicConstraints.notCertificateAuthority)
                    Critical(KeyUsage(digitalSignature: true, nonRepudiation: true, keyEncipherment: true, keyAgreement: true))
                    SubjectAlternativeNames([.dnsName(hostName)])
                }
            }
        
        let certificate = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: key.publicKey,
            notValidBefore: now,
            notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365 * 10),
            issuer: issuerName,
            subject: subjectName,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: issuerPrivateKey == nil ? key : Certificate.PrivateKey(issuerPrivateKey!)
        )
        
        return (certificate: certificate, key: swiftCryptoKey)
    }
    
    private func generateSelfSignedCertificate(hostName: String) throws -> (certificate: Certificate, key: P256.Signing.PrivateKey) {
        return try generateCertificate(hostName: hostName)
    }
    
    private func generateCertificateForDomain(_ domain: String, signedBy issuerPrivateKey: P256.Signing.PrivateKey) throws -> (certificate: Certificate, key: P256.Signing.PrivateKey) {
        return try generateCertificate(hostName: domain, issuerPrivateKey: issuerPrivateKey)
    }
    
    
    private func saveCertificateToKeychain(certificate: Certificate, withLabel label: String) {
        var serializer = DER.Serializer()
        try! serializer.serialize(certificate)
        
        let certificateData = Data(serializer.serializedBytes)
        
        let query = [kSecClass: kSecClassCertificate,
                 kSecAttrLabel: "RootCACertificate",
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
 kSecUseDataProtectionKeychain: true,
                 kSecValueData: certificateData] as [String: Any]
        
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            print("Error deleting existing certificate: \(deleteStatus)")
        }
        
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        if addStatus != errSecSuccess {
            print("Error adding certificate to the keychain: \(addStatus)")
        } else {
            print("Certificate successfully saved to keychain")
        }
    }
    
    private func saveToKeychain(privateKey: P256.Signing.PrivateKey) {
        let attributes = [kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                         kSecAttrKeyClass: kSecAttrKeyClassPrivate] as [String: Any]
        
        guard let secKey = SecKeyCreateWithData(privateKey.x963Representation as CFData,
                                                attributes as CFDictionary,
                                                nil) else {
            fatalError("Unable to create SecKey representation.")
        }
        
        let query = [kSecClass: kSecClassKey,
      kSecAttrApplicationLabel: "RootCAKey",
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
 kSecUseDataProtectionKeychain: true,
                  kSecValueRef: secKey] as [String: Any]
        
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            print("Error deleting existing key: \(deleteStatus)")
        }
        
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        if addStatus != errSecSuccess {
            print("Error adding key to the keychain: \(addStatus)")
        } else {
            print("Key successfully saved to keychain")
        }
    }
    
    func loadRootCAFromKeychain() throws -> (rootPrivateKey: P256.Signing.PrivateKey, rootCertificate: Certificate) {
        let keyQuery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationLabel: "RootCAKey",
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecReturnRef: true
        ]
        
        var keyItem: CFTypeRef?
        let keyStatus = SecItemCopyMatching(keyQuery as CFDictionary, &keyItem)
        
        guard keyStatus == errSecSuccess, let secKey = keyItem as! SecKey? else {
            try createRootCA()
            return try loadRootCAFromKeychain()
        }
        
        guard let privateKeyData = SecKeyCopyExternalRepresentation(secKey, nil) as Data? else {
            throw CertificateManagerError.privateKeyDecodingError
        }
        
        guard let rootPrivateKey = try? P256.Signing.PrivateKey(x963Representation: privateKeyData) else {
            throw CertificateManagerError.privateKeyDecodingError
        }
        
        let certQuery: [CFString: Any] = [
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: "RootCACertificate",
            kSecReturnRef: true
        ]
        
        var certItem: CFTypeRef?
        let certStatus = SecItemCopyMatching(certQuery as CFDictionary, &certItem)
        
        guard certStatus == errSecSuccess, let secCertificate = certItem as! SecCertificate? else {
            try createRootCA()
            return try loadRootCAFromKeychain()
        }
        
        let certData = SecCertificateCopyData(secCertificate) as Data
        let parsedData = try! DER.parse([UInt8](certData))
        
        guard let rootCertificate = try? Certificate(derEncoded: parsedData) else {
            throw CertificateManagerError.certificateDecodingError
        }
        
        return (rootPrivateKey: rootPrivateKey, rootCertificate: rootCertificate)
    }
    
    enum CertificateManagerError: Error {
        case privateKeyDecodingError
        case deleteRootKeyError
        case certificateDecodingError
    }
}
