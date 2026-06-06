import Foundation

enum ScreenTimeFetchError: LocalizedError {
    case missingUsageDataAccess(status: String)
    case activityDataUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingUsageDataAccess(let status):
            if status == "approved" {
                return """
                TikTok/YouTube usage charts need Apple’s “App & Website Usage” entitlement on this build \
                (current status: approved, need approvedWithDataAccess). \
                Ask the developer to confirm Family Controls distribution approval includes app-and-website-usage, then upload a new TestFlight build.
                """
            }
            return "Screen Time usage data is not available (status: \(status)). Re-authorize in Parent’s Access, or reinstall after a new build."
        case .activityDataUnavailable(let detail):
            return "Could not load Screen Time usage: \(detail)"
        }
    }
}
