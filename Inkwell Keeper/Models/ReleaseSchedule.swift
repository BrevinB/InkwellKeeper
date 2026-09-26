//
//  ReleaseSchedule.swift
//  Inkwell Keeper
//
//  Decides whether a set is still upcoming from its bundled `releaseDate`. The date itself is
//  the gate: new-set data can ship in an update weeks early, and the cards unlock (spoiler
//  shield lifts, tournament legality begins) at local midnight on release day with no further
//  update or server flag.
//

import Foundation

enum ReleaseSchedule {

    /// The local-calendar day a `yyyy-MM-dd` release date refers to, or nil if unparseable.
    ///
    /// Parsed into local date components rather than as an ISO-8601 instant, which would mean
    /// UTC midnight — in the Americas that's the evening *before* release day.
    static func releaseDay(from releaseDate: String?, calendar: Calendar = .current) -> Date? {
        guard let releaseDate else { return nil }
        let parts = releaseDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// True until local midnight on the release day. Sets with no or malformed dates are treated
    /// as released, so bad data can never hide cards indefinitely.
    static func isUpcoming(releaseDate: String?, asOf now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let day = releaseDay(from: releaseDate, calendar: calendar) else { return false }
        return calendar.startOfDay(for: now) < day
    }
}
