# FuseBar 1.3.2

A fix for the first click while typing in the panel's search field.

- **Clicking a row now works on the first try while an input method is composing.** The panel focuses its search field on open. With a composing input method (such as pinyin), the first click anywhere else in the panel was spent committing that composition: the row under the cursor never fired, and the committed text replaced the status rows with search results — switching the input source appeared to do nothing until a second attempt. FuseBar now discards the uncommitted composition before the click is dispatched, so the first click lands on the row and the half-typed pinyin is not turned into a search query. Clicking back into the search field still edits the composition as before.

FuseBar stays free and local: no accounts, ads, analytics, or subscriptions. It is distributed through GitHub releases and is not published on the Mac App Store.

## Install

Download `FuseBar-1.3.2-macOS.zip`, extract it, and move FuseBar to Applications. Quit a running older version before replacing it. Requires macOS 14 or later; the universal app supports Apple Silicon and Intel.

## Validation

82 XCTest and 25 Swift Testing checks pass, including three new tests for discarding the composition on row clicks while keeping it for clicks inside the field. The first-click behavior is verified live with a pinyin input method: with the composition active, the first click opens the input-source submenu and the selection switches, confirmed by reading the system input source back.
