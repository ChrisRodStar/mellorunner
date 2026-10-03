import Foundation
import SwiftSoup
import Testing
import WasmKit

@testable import MelloRunner

@Suite("HTML Imports Tests")
struct HTMLImportsTests {
    @Test("HTML parsing and CSS selector element extraction")
    func testHtmlParsingAndSelector() throws {
        let html = """
            <div id="content" class="main-body">
                <h1 class="title">Chapter 1: The Beginning</h1>
                <p class="description">An epic adventure begins.</p>
                <ul class="items">
                    <li data-index="0">Page 1</li>
                    <li data-index="1">Page 2</li>
                    <li data-index="2">Page 3</li>
                </ul>
            </div>
            """

        let doc = try SwiftSoup.parse(html)
        let resourceStore = ResourceStore()
        let docDesc = resourceStore.storeObject(doc)

        let retrievedDoc: Document? = resourceStore.fetchObject(docDesc)
        #expect(retrievedDoc != nil)

        let titleElem = try #require(try doc.select("h1.title").first())
        #expect(try titleElem.text() == "Chapter 1: The Beginning")

        let items = try doc.select("ul.items li")
        #expect(items.size() == 3)
        #expect(try items.get(1).text() == "Page 2")
        #expect(try items.get(1).attr("data-index") == "1")
    }

    @Test("HTML entity escaping and unescaping")
    func testEntityEscaping() throws {
        let raw = "<script>alert('XSS & fun');</script>"
        let escaped = Entities.escape(raw)
        #expect(!escaped.contains("<script>"))
        #expect(escaped.contains("&lt;script&gt;"))

        let unescaped = try Entities.unescape(escaped)
        #expect(unescaped == raw)
    }

    @Test("HTMLImports kind identification for different DOM nodes")
    func testKindIdentification() throws {
        let html = "<div id='test'>Hello <!-- comment --></div>"
        let doc = try SwiftSoup.parse(html)
        let element = try #require(try doc.select("#test").first())
        let elements = try doc.select("div")

        let resourceStore = ResourceStore()
        let docDesc = resourceStore.storeObject(doc)
        let elemDesc = resourceStore.storeObject(element)
        let elemsDesc = resourceStore.storeObject(elements)

        let htmlImports = HTMLImports(resourceStore: resourceStore)
        let store = Store(engine: Engine())
        _ = htmlImports.makeImports(store: store)

        let fetchedDoc: Document? = resourceStore.fetchObject(docDesc)
        let fetchedElem: Element? = resourceStore.fetchObject(elemDesc)
        let fetchedElems: Elements? = resourceStore.fetchObject(elemsDesc)

        #expect(fetchedDoc != nil)
        #expect(fetchedElem != nil)
        #expect(fetchedElems != nil)
        #expect(fetchedElem?.id() == "test")
        #expect(fetchedElems?.size() == 1)
    }

    @Test("DOM element mutation: class, attributes, and text")
    func testDomMutation() throws {
        let doc = try SwiftSoup.parse("<div id='box' class='one'>Original</div>")
        let elem = try #require(try doc.select("#box").first())

        try elem.addClass("two")
        #expect(elem.hasClass("two"))

        try elem.removeClass("one")
        #expect(!elem.hasClass("one"))

        try elem.attr("data-custom", "value123")
        #expect(elem.hasAttr("data-custom"))
        #expect(try elem.attr("data-custom") == "value123")

        try elem.text("Updated Text")
        #expect(try elem.text() == "Updated Text")
    }
}
