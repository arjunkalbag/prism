# Prism

A glass overlay for macOS that **hears your music and shows the key — live** — then
tells you what mixes next (DJ mode) or what to play next (Producer mode).

Prism floats on top of any DJ app (rekordbox, Serato, Traktor, djay, VirtualDJ) or DAW
(FL Studio, Ableton, Logic), listens to system audio, and detects the musical key in
real time — big, bold, and flicker-free. It's a real native `.app` (Swift + SwiftUI +
AppKit) — no browser, no Electron, no localhost.

```
┌──────────────────────────────┐
│  ● Prism            ● locked  │
│                               │
│  A                      ┌────┐│
│  minor                  │ 8A ││
│                         └────┘│
│  ▁▃▆▂█▄▆▂█▅▆▃   124 BPM        │
│  [    DJ    ] [  Producer  ]  │
│   ◴ Camelot wheel + mix list  │
└──────────────────────────────┘
```

## What it does

- **Live key detection** — chromagram → Krumhansl-Schmuckler key-profile correlation,
  shown in standard notation + Camelot code, with a confidence-gated "listening… → lock"
  so the readout never flickers. Secondary BPM readout via spectral-flux + autocorrelation.
- **DJ mode** — a color-coded Camelot wheel (outer ring = major/B, inner ring = minor/A)
  with the current key highlighted and compatible slots lit, plus a ranked "mix next" list
  (perfect / smooth ±1 / relative / energy +2 / dominant).
- **Producer mode** — the scale, diatonic chords with roman numerals, common progressions,
  relative/parallel keys, and an **optional** AI "creative directions" layer.

Detection and the core suggestions are 100% local and deterministic. AI is optional and
never blocks the live readout.

## Requirements

- **macOS 13 (Ventura) or newer** — required for ScreenCaptureKit audio and `MenuBarExtra`.
- Apple Silicon or Intel Mac.
- Xcode 15+ **or** the Command Line Tools (`xcode-select --install`) to build.

## Build & run

```bash
./Tools/setup-signing.sh # ONE TIME: create a stable local signing identity
./run.sh                 # debug build → assembles & launches Prism.app
./build.sh               # release build → build/Prism.app
./build.sh debug         # debug build
```

`build.sh` compiles with SwiftPM, assembles a proper `.app` bundle (Info.plist,
entitlements, icon, fonts) and code-signs it.

**Run `./Tools/setup-signing.sh` once first.** It creates a self-signed code-signing
identity ("Prism Local Signing") in your login keychain, and `build.sh` then signs with
it. This is what makes macOS **remember the Screen Recording permission** — an ad-hoc
signature's identity is just the binary hash, which changes on every build, so macOS would
otherwise re-ask for permission every time. With the stable identity the grant sticks
across rebuilds and relaunches. (Without the script, `build.sh` falls back to ad-hoc and
warns you.)

Prism is a normal **Dock app**: a resizable, closable glass window plus a menu-bar item
for quick controls. Close it with the window's red button, ⌘Q, or the Dock menu. Toggle
**Float on top** in the menu bar to keep it pinned above other apps (e.g. over a DJ deck).

### Grant Screen Recording permission (first run)

ScreenCaptureKit is the macOS path to system audio, and it's gated behind **Screen
Recording** permission. On first launch Prism shows an in-overlay prompt:

1. **System Settings → Privacy & Security → Screen Recording**
2. Enable **Prism**
3. Return to the overlay and hit **Retry** (or relaunch)

You only grant it **once** (provided you ran `setup-signing.sh`). If you ever switch
signing identity, run `tccutil reset ScreenCapture co.trycreate.prism` for a clean prompt.

Prism excludes its own audio from capture, so it never analyzes itself.

## Verify the analysis core

The deterministic Theory + DSP core ships with checks you can run **without Xcode**:

```bash
swift run PrismCheck      # 78 assertions: Camelot tables, mixing rules,
                          # diatonic spelling, key detection, FFT→chroma
```

There is also a standard **XCTest** suite (`Tests/PrismCoreTests`) for the Xcode test
navigator / CI. `swift test` requires a full Xcode install (XCTest is not bundled with the
Command Line Tools); `swift run PrismCheck` covers the same cases with no dependency.

## Hotkeys

| Shortcut | Action |
|----------|--------|
| `⌃⌥K`    | Show / hide the overlay |
| `⌃⌥T`    | Toggle click-through (mouse passes to the deck behind) |

Mode, opacity, click-through, detection profile and AI toggle also live in the menu-bar
item. Window position, size, opacity and mode persist across launches.

## Optional AI suggestions

Producer mode can call the Anthropic API for richer creative directions. It's **off by
default** and the app is fully functional without it.

```bash
export ANTHROPIC_API_KEY="sk-ant-…"      # or write the key to ~/.prism/anthropic_key
```

Then enable **AI suggestions** in the menu bar. The key is never hardcoded; calls use a
fast model (`claude-haiku-4-5`) and are made only when you click *Suggest ideas*.

## How it's built

```
Sources/
  PrismCore/        ← pure, portable, GUI-free (no AppKit) — the analysis core
    MusicalKey.swift, KeyEstimate.swift, RingBuffer.swift
    DSP/            FFTProcessor, ChromaExtractor, KeyProfiles, KeyDetector, TempoEstimator, Window
    Theory/         Camelot, MixingRules, Diatonic, KeyColor
  Prism/            ← the macOS app (depends on PrismCore)
    Audio/          AudioCaptureController (ScreenCaptureKit), AnalysisEngine
    Overlay/        OverlayPanel (NSPanel), OverlayController, GlassEffectView, HotkeyManager (Carbon)
    Views/          OverlayView, DJModeView, ProducerModeView, CamelotWheelView, ChromaMeterView, …
    AI/             AICoach (optional Anthropic client)
    AppModel.swift, AppDelegate.swift, PrismApp.swift
  PrismCheck/       ← dependency-free verification runner
Tests/PrismCoreTests/   ← XCTest suite
```

**Threading.** The ScreenCaptureKit delegate writes mono samples into a preallocated,
lock-light ring buffer on a capture queue. A separate analysis queue pulls windows
(`4096 @ Hann`, hop ~120 ms), runs chroma → key detection + tempo, smooths the estimate,
and publishes snapshots to the main actor for SwiftUI. The capture path allocates nothing.

**The window.** A standard titled, resizable `NSWindow` with a transparent full-size-content
title bar, so it keeps the traffic-light buttons (easy to close) while the glass runs edge
to edge. Glass is a behind-window `NSVisualEffectView` for a genuine frosted blur of
whatever's behind it. **Float on top** raises the window level to `.floating` (with
all-spaces / full-screen-auxiliary behavior) for an over-the-deck overlay; click-through
toggles `ignoresMouseEvents` (off by default, never persisted, so it can't trap the cursor).

> **Note on global hotkeys:** Prism uses a small self-contained Carbon `RegisterEventHotKey`
> manager rather than the external `KeyboardShortcuts` package, to avoid a network-fetched
> dependency. The behavior (and the `⌃⌥K` / `⌃⌥T` defaults) is the same.

## Fallback: BlackHole

If you need isolated audio (capture only one app) or you're on older macOS, route audio
through [BlackHole](https://github.com/ExistentialAudio/BlackHole):

1. Install BlackHole (2ch).
2. Create a **Multi-Output Device** (your speakers + BlackHole) in *Audio MIDI Setup* so you
   still hear sound, and send your DJ/DAW output there.
3. ScreenCaptureKit still captures the system mix; for a fully isolated feed, point Prism's
   capture at the BlackHole device.

On macOS 14.2+, Prism can also capture a **specific app's** audio instead of the full system
mix.

## Windows (later)

The `PrismCore` DSP/Theory core is deliberately AppKit-free and portable. A Windows port
would reuse it wholesale and swap the platform layer for **WASAPI loopback** (system-audio
capture) and **DWM acrylic** (glass), with the same chroma → Krumhansl-Schmuckler →
Camelot/diatonic pipeline.

---

Built natively in Swift. `Accelerate / vDSP` for the FFT, `ScreenCaptureKit` for capture,
`SwiftUI + AppKit` for the glass.
