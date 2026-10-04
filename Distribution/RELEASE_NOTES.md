# FuseBar 1.3.1

A fix for keyboard navigation in search.

- **↑/↓ and Return now work while an input method is composing.** With pinyin or another composing input method, the arrow keys and Return went to the input method's candidate window, so they could not move through search results or open the selection. FuseBar now handles ↑, ↓, Return, and keypad Enter in the search field before the input method whenever there are results. Without results, the keys still reach the input method; ← and →, and keys pressed with ⌘, ⌃, ⌥, or ⇧, are unchanged.

FuseBar stays free and local: no accounts, ads, analytics, or subscriptions. It is distributed through GitHub releases and is not published on the Mac App Store.

## Install

Download `FuseBar-1.3.1-macOS.zip`, extract it, and move FuseBar to Applications. Quit a running older version before replacing it. Requires macOS 14 or later; the universal app supports Apple Silicon and Intel.

## Validation

79 XCTest and 25 Swift Testing checks pass, including new tests for the key mapping and for handling ↓ and Return before the field editor. Third-party input methods cannot be driven reliably in automated tests, so behavior while composing is confirmed by hand on a Mac with such an input method.
