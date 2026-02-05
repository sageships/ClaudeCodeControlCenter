import Foundation

/// Handles JSON persistence to Application Support directory
class PersistenceService {
    private let dataDirectory: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.dataDirectory = appSupport.appendingPathComponent("ClaudeCodeControlCenter/data")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
    }
    
    /// Save an encodable object to a JSON file
    func save<T: Encodable>(_ object: T, to filename: String) throws {
        let url = dataDirectory.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(object)
        try data.write(to: url)
    }
    
    /// Load a decodable object from a JSON file
    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let url = dataDirectory.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    /// Check if a file exists
    func fileExists(_ filename: String) -> Bool {
        let url = dataDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Delete a file
    func delete(_ filename: String) throws {
        let url = dataDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: url)
    }
}
