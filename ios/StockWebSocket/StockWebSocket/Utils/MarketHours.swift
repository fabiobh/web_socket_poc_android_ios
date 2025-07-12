import Foundation

public class MarketHours {
    public static let shared = MarketHours()
    
    public init() {}
    
    /// Checks if the US stock market is currently open
    /// - Returns: A tuple with a boolean indicating if the market is open, and a status message
    public func isUSMarketOpen() -> (isOpen: Bool, statusMessage: String) {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the current date and time in Eastern Time
        let easternTimeZone = TimeZone(identifier: "America/New_York")!
        var easternCalendar = calendar
        easternCalendar.timeZone = easternTimeZone
        
        let components = easternCalendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: now)
        
        // Check if it's a weekday (1 = Sunday, 7 = Saturday)
        guard let weekday = components.weekday, weekday >= 2 && weekday <= 6 else {
            return (false, "Market is closed (weekend)")
        }
        
        // Check if it's a market holiday (simplified - would need to be expanded for all market holidays)
        if isMarketHoliday(date: now, in: easternCalendar) {
            return (false, "Market is closed (holiday)")
        }
        
        // Market hours: 9:30 AM to 4:00 PM Eastern Time
        let marketOpen = DateComponents(timeZone: easternTimeZone, 
                                      year: components.year, 
                                      month: components.month, 
                                      day: components.day, 
                                      hour: 9, 
                                      minute: 30)
        
        let marketClose = DateComponents(timeZone: easternTimeZone, 
                                       year: components.year, 
                                       month: components.month, 
                                       day: components.day, 
                                       hour: 16, 
                                       minute: 0)
        
        guard let openTime = calendar.date(from: marketOpen),
              let closeTime = calendar.date(from: marketClose) else {
            return (false, "Unable to determine market hours")
        }
        
        let isOpen = (openTime...closeTime).contains(now)
        
        if isOpen {
            return (true, "Market is open")
        } else {
            let formatter = DateFormatter()
            formatter.timeZone = easternTimeZone
            formatter.timeStyle = .short
            
            if now < openTime {
                return (false, "Market opens at 9:30 AM ET")
            } else {
                return (false, "Market closed. Opens tomorrow at 9:30 AM ET")
            }
        }
    }
    
    /// Simplified check for market holidays (would need to be expanded for all market holidays)
    private func isMarketHoliday(date: Date, in calendar: Calendar) -> Bool {
        // This is a simplified version - would need to be expanded for all market holidays
        let components = calendar.dateComponents([.month, .day, .weekday, .weekdayOrdinal], from: date)
        
        // New Year's Day (January 1st, or the following Monday if it's a weekend)
        if components.month == 1 && components.day == 1 {
            return true
        }
        
        // Add other major holidays here (MLK Day, Presidents' Day, Good Friday, etc.)
        
        return false
    }
    
    /// Returns the next market open time
    func nextMarketOpenTime() -> Date? {
        let calendar = Calendar.current
        let easternTimeZone = TimeZone(identifier: "America/New_York")!
        var easternCalendar = calendar
        easternCalendar.timeZone = easternTimeZone
        
        var dateComponents = easternCalendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: Date())
        
        // Set to 9:30 AM
        dateComponents.hour = 9
        dateComponents.minute = 30
        
        guard var nextOpen = easternCalendar.date(from: dateComponents) else { return nil }
        
        // If it's after 9:30 AM, set to tomorrow
        if nextOpen < Date() {
            nextOpen = calendar.date(byAdding: .day, value: 1, to: nextOpen) ?? nextOpen
        }
        
        // Adjust for weekends
        while true {
            let weekday = calendar.component(.weekday, from: nextOpen)
            if weekday != 1 && weekday != 7 { // Not Sunday (1) or Saturday (7)
                break
            }
            nextOpen = calendar.date(byAdding: .day, value: 1, to: nextOpen) ?? nextOpen
        }
        
        return nextOpen
    }
}
