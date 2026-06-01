import Foundation

enum DateUtils {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let shortDayWithYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func displayDate(_ date: Date, relativeTo referenceDate: Date = Date()) -> String {
        let calendar = Calendar.current
        let dateYear = calendar.component(.year, from: date)
        let referenceYear = calendar.component(.year, from: referenceDate)
        if dateYear == referenceYear {
            return shortDayFormatter.string(from: date)
        }
        return shortDayWithYearFormatter.string(from: date)
    }

    static func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    static func isDate(_ date: Date?, inSameDayAs other: Date) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, inSameDayAs: other)
    }

    static func humanDuration(from start: Date, to end: Date) -> String {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let days = max(calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0, 0) + 1

        if days < 14 {
            return "\(days) day\(days == 1 ? "" : "s")"
        }

        if days < 60 {
            let weeks = max(1, Int((Double(days) / 7.0).rounded()))
            return "\(weeks) week\(weeks == 1 ? "" : "s")"
        }

        if days < 730 {
            let months = max(1, Int((Double(days) / 30.44).rounded()))
            return "\(months) month\(months == 1 ? "" : "s")"
        }

        let years = max(1, Int((Double(days) / 365.25).rounded()))
        return "\(years) year\(years == 1 ? "" : "s")"
    }

    static func datesForMonth(containing date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else { return [] }

        var dates: [Date] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            dates.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }
        return dates
    }

    static func isDateInCurrentWeek(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    static func isDateInCurrentMonth(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }
}
