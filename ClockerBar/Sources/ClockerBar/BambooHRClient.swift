import Foundation

struct BambooHRConfig {
    let apiKey: String
    let companyDomain: String
    let employeeId: String
}

struct ProjectInfo: Codable {
    let id: Int
    let name: String
}

struct TimesheetEntry: Codable {
    let id: Int
    let employeeId: Int
    let type: String
    let date: String
    let start: String?
    let end: String?
    let timezone: String?
    let hours: Double?
    let note: String?
    let projectInfo: ProjectInfo?
    let approved: Bool
    let approvedAt: String?
    
    var isActiveClockEntry: Bool {
        type == "clock" && start != nil && end == nil
    }
}

struct ClockResponse: Codable {
    let id: Int
    let employeeId: Int
    let type: String
    let date: String
    let start: String?
    let end: String?
    let timezone: String?
    let hours: Double?
    let note: String?
    let projectInfo: ProjectInfo?
}

enum BambooHRError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

class BambooHRClient {
    private let config: BambooHRConfig
    private let session: URLSession
    
    init(config: BambooHRConfig) {
        self.config = config
        self.session = URLSession.shared
    }
    
    private var baseURL: String {
        "https://api.bamboohr.com/api/gateway.php/\(config.companyDomain)/v1"
    }
    
    private var authHeader: String {
        let credentials = "\(config.apiKey):x"
        let data = credentials.data(using: .utf8)!
        return "Basic \(data.base64EncodedString())"
    }
    
    private func request<T: Decodable>(
        method: String,
        path: String,
        body: Data? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BambooHRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BambooHRError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BambooHRError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BambooHRError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        
        if httpResponse.statusCode == 204 || data.isEmpty {
            if let empty = EmptyResponse() as? T {
                return empty
            }
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw BambooHRError.decodingError(error)
        }
    }
    
    func getTimesheetEntries(start: String, end: String) async throws -> [TimesheetEntry] {
        var components = URLComponents(string: "\(baseURL)/time_tracking/timesheet_entries")!
        components.queryItems = [
            URLQueryItem(name: "start", value: start),
            URLQueryItem(name: "end", value: end),
            URLQueryItem(name: "employeeIds", value: config.employeeId)
        ]
        
        guard let url = components.url else {
            throw BambooHRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BambooHRError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BambooHRError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BambooHRError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        
        do {
            return try JSONDecoder().decode([TimesheetEntry].self, from: data)
        } catch {
            throw BambooHRError.decodingError(error)
        }
    }
    
    func clockIn() async throws -> ClockResponse {
        let body = try JSONEncoder().encode(EmptyBody())
        return try await request(
            method: "POST",
            path: "/time_tracking/employees/\(config.employeeId)/clock_in",
            body: body
        )
    }
    
    func clockOut() async throws -> ClockResponse {
        let body = try JSONEncoder().encode(EmptyBody())
        return try await request(
            method: "POST",
            path: "/time_tracking/employees/\(config.employeeId)/clock_out",
            body: body
        )
    }
}

private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}

struct Employee {
    let id: String
    let displayName: String
}

struct EmployeeDirectoryResponse: Decodable {
    let employees: [DirectoryEmployee]
    
    struct DirectoryEmployee: Decodable {
        let id: String
        let displayName: String?
        let firstName: String?
        let lastName: String?
    }
}

class EmployeeSearch {
    static func searchEmployees(apiKey: String, companyDomain: String) async throws -> [Employee] {
        let baseURL = "https://api.bamboohr.com/api/gateway.php/\(companyDomain)/v1"
        let credentials = "\(apiKey):x"
        let authHeader = "Basic \(credentials.data(using: .utf8)!.base64EncodedString())"
        
        guard let url = URL(string: "\(baseURL)/employees/directory") else {
            throw BambooHRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BambooHRError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BambooHRError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        
        let directoryResponse = try JSONDecoder().decode(EmployeeDirectoryResponse.self, from: data)
        
        return directoryResponse.employees.compactMap { emp -> Employee? in
            let name = emp.displayName ?? [emp.firstName, emp.lastName].compactMap { $0 }.joined(separator: " ")
            guard !name.isEmpty else { return nil }
            return Employee(id: emp.id, displayName: name)
        }
    }
}
