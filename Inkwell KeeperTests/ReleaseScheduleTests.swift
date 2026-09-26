//
//  ReleaseScheduleTests.swift
//  Inkwell KeeperTests
//
//  The release date is the spoiler/legality gate, so it must flip at LOCAL midnight — not UTC
//  midnight, which in the Americas is the evening before release day.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct ReleaseScheduleTests {
    private var pacific: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        return calendar
    }

    private func instant(_ iso: String) throws -> Date {
        try Date(iso, strategy: .iso8601)
    }

    @Test("Upcoming the evening before release, even after UTC midnight")
    func upcomingEveningBefore() throws {
        // Oct 15, 11:30 PM Pacific — already Oct 16 in UTC.
        let now = try instant("2026-10-16T06:30:00Z")
        #expect(ReleaseSchedule.isUpcoming(releaseDate: "2026-10-16", asOf: now, calendar: pacific))
    }

    @Test("Released from local midnight on release day")
    func releasedAtLocalMidnight() throws {
        // Oct 16, 12:00 AM Pacific.
        let now = try instant("2026-10-16T07:00:00Z")
        #expect(!ReleaseSchedule.isUpcoming(releaseDate: "2026-10-16", asOf: now, calendar: pacific))
    }

    @Test("Past sets are not upcoming")
    func pastSet() throws {
        let now = try instant("2026-10-16T12:00:00Z")
        #expect(!ReleaseSchedule.isUpcoming(releaseDate: "2026-07-17", asOf: now, calendar: pacific))
    }

    @Test("Missing or malformed dates never hide a set", arguments: [nil, "", "TBD", "2026-10"])
    func badDatesAreReleased(releaseDate: String?) {
        #expect(!ReleaseSchedule.isUpcoming(releaseDate: releaseDate, asOf: .distantPast))
    }
}
