# Changelog

All notable changes to this project will be documented in this file.

## [0.0.2] - 2026-03-21

### Added
- Full Chinese (Simplified) localization via `Localizable.xcstrings`.
- Local Terminal support powered by the native Ghostty engine.
- SFTP panel with file browsing and transfer; fixed race condition crash on first open.
- Mouse scroll wheel / trackpad scrolling support inside the terminal.

### Fixed
- Local terminal shell crashing on launch due to empty environment; now injects the host Mac's environment variables.
- Starship prompt reporting `TERM=dumb` error inside terminal; forced `TERM=xterm-256color`.
- Terminal content compressed to very few columns; fixed `setFrameSize` not triggering Ghostty dimension recalculation.
- Terminal view rendered underneath the sidebar; removed incorrect `.ignoresSafeArea()` modifier.
- SSH session socket not released when closing a tab, causing background resource leak; added async `deinit` cleanup.

### Removed
- Deprecated legacy VT100 source files (`AnsiParser`, `GhosttyVTBridge`, etc.).

---

## [0.0.1] - 2026-03-20

### Added
- Initial release of MacSSH.
- Integrated Ghostty terminal engine for high-performance rendering.
- Added full ANSI color support (256-color and 24-bit TrueColor).
- Integrated SFTP panel with file browsing and transfer capabilities.
- Added localized UI support.
- Implemented non-blocking SSH I/O to prevent UI/Terminal deadlocks.
- Configured Git LFS for efficient binary dependency management.
- Optimized repository size by excluding 2.4GB of redundant build artifacts.
