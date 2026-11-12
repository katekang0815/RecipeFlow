//
//  SourceLinkTests.swift
//  RecipeFlowTests
//

import Testing
import Foundation
@testable import RecipeFlow

struct SourceLinkTests {
    private let youtube = "https://www.youtube.com/watch?v=nqsoMyxHTbc&list=PL18IRmCF_TjT-T2HX2hulARtaTOkikNvG&index=6"

    // MARK: url(from:)

    @Test func acceptsHttpAndHttpsLinks() {
        #expect(SourceLink.url(from: youtube)?.absoluteString == youtube)
        #expect(SourceLink.url(from: "http://example.com/recipe")?.absoluteString == "http://example.com/recipe")
        #expect(SourceLink.url(from: "HTTPS://Example.com/Pizza") != nil)
    }

    @Test func addsHttpsWhenTheBrowserHidItAndTrimsSpaces() {
        #expect(SourceLink.url(from: "youtube.com/watch?v=abc")?.absoluteString == "https://youtube.com/watch?v=abc")
        #expect(SourceLink.url(from: "  https://example.com/a\n")?.absoluteString == "https://example.com/a")
    }

    @Test func rejectsAnythingThatIsNotAWebLink() {
        #expect(SourceLink.url(from: "") == nil)
        #expect(SourceLink.url(from: "   ") == nil)
        #expect(SourceLink.url(from: "hello") == nil)
        #expect(SourceLink.url(from: "3.5") == nil)
        #expect(SourceLink.url(from: "two words.com") == nil)
        #expect(SourceLink.url(from: "https://") == nil)
        #expect(SourceLink.url(from: "http://localhost:8080") == nil)
    }

    @Test func rejectsLinksThatHideTheRealSiteBehindAUsername() {
        #expect(SourceLink.url(from: "https://www.google.com@evil.example.net/login") == nil)
        #expect(SourceLink.url(from: "https://user:pass@example.com") == nil)
    }

    @Test func rejectsOtherSchemes() {
        #expect(SourceLink.url(from: "ftp://example.com/file") == nil)
        #expect(SourceLink.url(from: "javascript:alert(1)") == nil)
        #expect(SourceLink.url(from: "mailto:someone@example.com") == nil)
        #expect(SourceLink.url(from: "tel://5551234567") == nil)
        #expect(SourceLink.url(from: "myapp://open?x=1") == nil)
    }

    // MARK: firstLink(in:)

    @Test func findsTheLinkInRealOCROutputWithBookmarkBarJunk() {
        // What Vision returned for a screenshot of the Safari address bar and bookmarks.
        let ocr = """
        >
        *
        Travel v
        N
        \(youtube)
        °
        g
        Design v
        House v
        """
        #expect(SourceLink.firstLink(in: ocr)?.absoluteString == youtube)
    }

    @Test func takesTheFirstOfSeveralLinks() {
        let text = "see https://first.example.com/a and https://second.example.com/b"
        #expect(SourceLink.firstLink(in: text)?.absoluteString == "https://first.example.com/a")
    }

    @Test func findsALinkWithoutTheScheme() {
        #expect(SourceLink.firstLink(in: "Travel v\nyoutube.com/watch?v=abc\nN") != nil)
    }

    @Test func ignoresEmailAddressesAndPlainText() {
        #expect(SourceLink.firstLink(in: "write to someone@example.com") == nil)
        #expect(SourceLink.firstLink(in: "Travel v\nDesign v\n3.5") == nil)
        #expect(SourceLink.firstLink(in: "") == nil)
    }
}
