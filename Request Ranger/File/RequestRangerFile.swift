import SwiftUI
import UniformTypeIdentifiers
import AppleArchive
import System

/** Save file that is written to the disk. The file is a LZFSE compressed directory containing of several JSON files. */
struct RequestRangerFile: FileDocument {
    static var readableContentTypes = [UTType(exportedAs: "net.authentick.RequestRanger.SaveFile", conformingTo: .appleArchive)]
    
    var proxyData: ProxyData
    var comparisonData: ComparisonData
    
    init(proxyData: ProxyData, comparisonData: ComparisonData) {
        self.proxyData = proxyData
        self.comparisonData = comparisonData
    }
    
    init(data: Data) throws {
        let archiveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try data.write(to: archiveURL)

        defer {
            try? FileManager.default.removeItem(at: archiveURL)
        }
        
        let filePath = FilePath(archiveURL.path)
        guard let readFileStream = ArchiveByteStream.fileStream(path: filePath, mode: .readOnly, options: [], permissions: FilePermissions(rawValue: 0o644)) else {
            fatalError("Opening file stream failed")
        }
        defer {
            try? readFileStream.close()
        }
        
        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream) else {
            fatalError("Decompression stream failed")
        }
        
        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
            fatalError("Decode stream failed")
        }
        defer {
            try? decodeStream.close()
        }
               
        let decompressPath = NSTemporaryDirectory() + "/" + UUID().uuidString
        if !FileManager.default.fileExists(atPath: decompressPath) {
            do {
                try FileManager.default.createDirectory(atPath: decompressPath,
                                                        withIntermediateDirectories: false)
            } catch {
                fatalError("Unable to create destination directory.")
            }
        }
        
        let decompressDestination = FilePath(decompressPath)
        guard let extractStream = ArchiveStream.extractStream(extractingTo: decompressDestination,
                                                              flags: [ .ignoreOperationNotPermitted ]) else {
            fatalError("Extract stream failed")
        }
        defer {
            try? extractStream.close()
        }

        do {
            _ = try ArchiveStream.process(readingFrom: decodeStream,
                                          writingTo: extractStream)
        } catch {
            fatalError("Decoding failed")
        }
        try? extractStream.close()

        let jsonDecoder = JSONDecoder()
        let proxyHistoryURL = URL(filePath: decompressPath + "/proxy_history.json")
        let proxyHistoryData = try Data(contentsOf: proxyHistoryURL)

        let savedRequests = try jsonDecoder.decode([HttpRequestForSaving].self, from: proxyHistoryData)
        self.proxyData = ProxyData()
        self.proxyData.httpRequests = savedRequests.map { entry -> ProxiedHttpRequest in
            let request = ProxiedHttpRequest()
            request.rawRequest = entry.rawRequest
            request.response = ProxiedHttpResponse()
            request.response!.rawResponse = entry.rawResponse ?? ""
            return request
        }
        
        let compareStringsURL = URL(filePath: decompressPath + "/compare_strings.json")
        let compareStringsData = try Data(contentsOf: compareStringsURL)
        let savedComparisonStrings = try jsonDecoder.decode([ComparisonStringForSaving].self, from: compareStringsData)
        self.comparisonData = ComparisonData()
        self.comparisonData.data = savedComparisonStrings.map { entry -> ComparisonData.CompareEntry in
            return ComparisonData.CompareEntry(id: entry.id, value: entry.string)
        }
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            fatalError("Could not read file content")
        }
        
        try self.init(data: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let fileWrapper = FileWrapper(directoryWithFileWrappers: [:])
        let jsonEncoder = JSONEncoder()
        
        let requests = proxyData.httpRequests.map { entry -> HttpRequestForSaving in
            return HttpRequestForSaving(rawRequest: entry.rawRequest, rawResponse: entry.response?.rawResponse, date: Date())
        }
        let requestJson = try jsonEncoder.encode(requests)
        let requestJsonFile = FileWrapper(regularFileWithContents: requestJson)
        requestJsonFile.preferredFilename = "proxy_history.json"
        fileWrapper.addFileWrapper(requestJsonFile)
        
        let comparisonStrings = comparisonData.data.map { entry -> ComparisonStringForSaving in
            return ComparisonStringForSaving(id: entry.id, string: entry.value)
        }
        let compareJson = try jsonEncoder.encode(comparisonStrings)
        let compareJsonFile = FileWrapper(regularFileWithContents: compareJson)
        compareJsonFile.preferredFilename = "compare_strings.json"
        fileWrapper.addFileWrapper(compareJsonFile)
        
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fileWrapper.write(to: tempDirectory, options: .atomic, originalContentsURL: nil)
        
        defer {
            try! FileManager.default.removeItem(atPath: tempDirectory.path(percentEncoded: false))
        }
        
        let archivePath = NSTemporaryDirectory() + "/" + UUID().uuidString
        let archiveURL = archivePath + "/archive.aar"
        let filePath = FilePath(archiveURL)
        
        if !FileManager.default.fileExists(atPath: archivePath) {
            do {
                try FileManager.default.createDirectory(atPath: archivePath,
                                                        withIntermediateDirectories: false)
            } catch {
                fatalError("Unable to create destination directory.")
            }
        }

        FileManager.default.createFile(atPath: filePath.string, contents: nil)
        guard let writeFileStream = ArchiveByteStream.fileStream(
            path: filePath,
            mode: .writeOnly,
            options: [ .create ],
            permissions: FilePermissions(rawValue: 0o644)) else {
            fatalError("Creating file stream failed")
        }
        defer {
            try? writeFileStream.close()
        }
        
        guard let compressStream = ArchiveByteStream.compressionStream(
            using: .lzfse,
            writingTo: writeFileStream) else {
            fatalError("Compression stream failed")
        }
        defer {
            try? compressStream.close()
        }
        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
            fatalError("Encode stream failed")
        }
        defer {
            try? encodeStream.close()
        }
        
        do {
            try encodeStream.writeDirectoryContents(
                archiveFrom: FilePath(tempDirectory.path(percentEncoded: false)),
                keySet: ArchiveHeader.FieldKeySet.defaultForArchive)
        } catch {
            fatalError("Write directory contents failed.")
        }
        
        return try FileWrapper(url: URL(filePath: archiveURL))
    }
}
