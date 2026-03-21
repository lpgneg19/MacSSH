# Changelog

All notable changes to this project will be documented in this file.

## [0.0.2] - 2026-03-21

### Added
- 中文界面全量本地化（`Localizable.xcstrings`）。
- 本地终端（Local Terminal）完整支持，搭载原生 Ghostty 引擎。
- SFTP 面板支持文件浏览与传输，解决了初次打开时的竞态崩溃问题。
- 鼠标滚轮/触控板在终端内支持滚动浏览历史输出。

### Fixed
- 本地终端启动时 Shell 环境变量为空导致崩溃；注入宿主 Mac 系统环境变量。
- Starship 提示符在终端内报错 `TERM=dumb`；强制设定 `TERM=xterm-256color`。
- 终端内容被压缩至极少列宽；修复了 `setFrameSize` 不触发 Ghostty 尺寸重算的问题。
- 终端视图被侧边栏遮挡；移除了错误的 `.ignoresSafeArea()` 修饰符。
- 关闭标签页时 SSH 会话 Socket 未释放导致后台资源泄漏；添加 `deinit` 异步清理逻辑。

### Removed
- 已废弃的旧版 VT100 源文件（`AnsiParser`、`GhosttyVTBridge` 等）。

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
