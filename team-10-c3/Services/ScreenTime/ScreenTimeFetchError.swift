import Foundation

enum ScreenTimeFetchError: LocalizedError {
    case missingUsageDataAccess(status: String)
    case activityDataUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingUsageDataAccess(let status):
            return "Screen Time needs “usage data access” (approvedWithDataAccess). Current status: \(status). Re-authorize in Parent’s Access after enabling App and Website Usage in Xcode, then reinstall."
        case .activityDataUnavailable(let detail):
            return "Could not load Screen Time usage: \(detail)"
        }
    }
}
