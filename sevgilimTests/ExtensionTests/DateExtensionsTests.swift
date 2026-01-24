//
//  DateExtensionsTests.swift
//  sevgilimTests
//
//  Unit tests for Date extension methods
//

import XCTest
@testable import sevgilim

final class DateExtensionsTests: XCTestCase {
    
    // MARK: - timeAgo() Tests
    
    func testTimeAgo_justNow() {
        let date = Date()
        XCTAssertEqual(date.timeAgo(), "Az önce")
    }
    
    func testTimeAgo_oneMinuteAgo() {
        let date = Date().addingTimeInterval(-60)
        XCTAssertEqual(date.timeAgo(), "1 dakika önce")
    }
    
    func testTimeAgo_multipleMinutesAgo() {
        let date = Date().addingTimeInterval(-300) // 5 dakika
        XCTAssertEqual(date.timeAgo(), "5 dakika önce")
    }
    
    func testTimeAgo_oneHourAgo() {
        let date = Date().addingTimeInterval(-3600)
        XCTAssertEqual(date.timeAgo(), "1 saat önce")
    }
    
    func testTimeAgo_multipleHoursAgo() {
        let date = Date().addingTimeInterval(-7200) // 2 saat
        XCTAssertEqual(date.timeAgo(), "2 saat önce")
    }
    
    func testTimeAgo_yesterday() {
        let date = Date().addingTimeInterval(-86400)
        XCTAssertEqual(date.timeAgo(), "Dün")
    }
    
    func testTimeAgo_daysAgo() {
        let date = Date().addingTimeInterval(-86400 * 5)
        XCTAssertEqual(date.timeAgo(), "5 gün önce")
    }
    
    func testTimeAgo_oneMonthAgo() {
        let date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        XCTAssertEqual(date.timeAgo(), "1 ay önce")
    }
    
    func testTimeAgo_multipleMonthsAgo() {
        let date = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        XCTAssertEqual(date.timeAgo(), "3 ay önce")
    }
    
    func testTimeAgo_oneYearAgo() {
        let date = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        XCTAssertEqual(date.timeAgo(), "1 yıl önce")
    }
    
    func testTimeAgo_multipleYearsAgo() {
        let date = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        XCTAssertEqual(date.timeAgo(), "2 yıl önce")
    }
    
    // MARK: - daysBetween() Tests
    
    func testDaysBetween_sameDay() {
        let date = Date()
        XCTAssertEqual(date.daysBetween(date), 0)
    }
    
    func testDaysBetween_oneDay() {
        let start = Date()
        let end = start.addingTimeInterval(86400)
        XCTAssertEqual(start.daysBetween(end), 1)
    }
    
    func testDaysBetween_oneWeek() {
        let start = Date()
        let end = start.addingTimeInterval(86400 * 7)
        XCTAssertEqual(start.daysBetween(end), 7)
    }
    
    func testDaysBetween_oneMonth() {
        let start = Date()
        let end = start.addingTimeInterval(86400 * 30)
        XCTAssertEqual(start.daysBetween(end), 30)
    }
    
    // MARK: - formattedDifference() Tests
    
    func testFormattedDifference_today() {
        let date = Date()
        XCTAssertEqual(date.formattedDifference(from: date), "Bugün")
    }
    
    func testFormattedDifference_daysOnly() {
        let start = Date()
        let end = start.addingTimeInterval(86400 * 5)
        let result = end.formattedDifference(from: start)
        XCTAssertTrue(result.contains("5 gün"))
    }
    
    func testFormattedDifference_oneYear() {
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let now = Date()
        let result = now.formattedDifference(from: start)
        XCTAssertTrue(result.contains("1 yıl"))
    }
    
    func testFormattedDifference_yearAndMonths() {
        var components = DateComponents()
        components.year = -1
        components.month = -3
        let start = Calendar.current.date(byAdding: components, to: Date())!
        let now = Date()
        let result = now.formattedDifference(from: start)
        XCTAssertTrue(result.contains("1 yıl"))
        XCTAssertTrue(result.contains("3 ay"))
    }
}
