import Foundation

struct ClockStatus {
    let isClockedIn: Bool
    let clockedInSince: String?
    let todayTotalHours: Double
    let currentEntry: TimesheetEntry?
}

enum ClockerError: Error, LocalizedError {
    case missingCredentials
    case apiError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Credentials not configured"
        case .apiError(let error):
            return error.localizedDescription
        }
    }
}

class ClockerService {
    private var client: BambooHRClient
    
    init() throws {
        guard let config = KeychainManager.getConfig() else {
            throw ClockerError.missingCredentials
        }
        self.client = BambooHRClient(config: config)
    }
    
    func reloadConfig() throws {
        guard let config = KeychainManager.getConfig() else {
            throw ClockerError.missingCredentials
        }
        self.client = BambooHRClient(config: config)
    }
    
    func getStatus() async throws -> ClockStatus {
        let today = formatDateToYYYYMMDD(Date())
        let entries: [TimesheetEntry]
        
        do {
            entries = try await client.getTimesheetEntries(start: today, end: today)
        } catch {
            throw ClockerError.apiError(error)
        }
        
        let activeEntry = entries.first { $0.isActiveClockEntry }
        let totalHours = calculateTotalHours(entries: entries, currentEntry: activeEntry)
        
        return ClockStatus(
            isClockedIn: activeEntry != nil,
            clockedInSince: activeEntry?.start,
            todayTotalHours: totalHours,
            currentEntry: activeEntry
        )
    }
    
    func toggle() async throws {
        let status = try await getStatus()
        if status.isClockedIn {
            _ = try await client.clockOut()
        } else {
            _ = try await client.clockIn()
        }
    }
    
    func clockIn() async throws {
        _ = try await client.clockIn()
    }
    
    func clockOut() async throws {
        _ = try await client.clockOut()
    }
    
    private func formatDateToYYYYMMDD(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    private func calculateTotalHours(entries: [TimesheetEntry], currentEntry: TimesheetEntry?) -> Double {
        let completedHours = entries
            .filter { $0.type == "clock" && $0.hours != nil }
            .reduce(0.0) { $0 + ($1.hours ?? 0) }
        
        guard let current = currentEntry, let startString = current.start else {
            return completedHours
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let startDate = formatter.date(from: startString) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: startString)
        }() else {
            return completedHours
        }
        
        let currentHours = Date().timeIntervalSince(startDate) / 3600
        return completedHours + currentHours
    }
}
