# CueShot product context

CueShot is a native macOS SwiftUI screenshot utility for exact capture and handoff into Codex and ChatGPT-like workflows. It is menu-bar-first, clipboard-first, and local-first.

## Product promise

CueShot should feel like a small, calm Mac capture instrument: choose what you want, capture it, confirm the result, then copy, paste, drag, save, or reveal it. It should not feel like configuring a developer tool.

## Core users

- Developers and technical writers who need to capture precise UI elements for AI/code review workflows.
- Power users who want fast global shortcuts and a floating capture HUD.
- Normal Mac users who need plain-language setup, clear permissions, and confidence that their screenshots are copied locally.

## Core workflow

1. Choose a capture mode: Element, Selection, Area, Window, Screen, or OCR/Text.
2. Use the floating capture control to capture by clicking or dragging.
3. CueShot copies a PNG to the clipboard and stores local history under Application Support.
4. The user can paste, drag, save, reveal, or copy OCR text.
5. Optional visible paste into Codex may send a paste command, but CueShot must never claim the image attached unless it can verify that result.

## Design direction

Quiet capture instrument, not control room. Make the floating control the hero interaction, show one dominant next action per state, and move metadata, permissions detail, handoff caveats, and diagnostics behind Details or Troubleshooting.

Use native macOS patterns, system appearance, semantic SwiftUI typography, restrained accent colors, and purposeful motion only for state clarity. Preserve capture engine behavior, permission services, history storage, clipboard semantics, shortcuts, and Codex handoff honesty.
