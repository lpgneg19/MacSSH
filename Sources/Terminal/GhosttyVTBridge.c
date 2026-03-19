#include "GhosttyVTBridge.h"
#include <ghostty_vt/vt.h>
#include <stdlib.h>

void *GhosttyVTCreateTerminal(uint16_t cols, uint16_t rows, size_t scrollback) {
    GhosttyTerminal terminal = NULL;
    GhosttyTerminalOptions options = (GhosttyTerminalOptions){
        .cols = cols,
        .rows = rows,
        .max_scrollback = scrollback,
    };
    GhosttyResult result = ghostty_terminal_new(NULL, &terminal, options);
    if (result != GHOSTTY_SUCCESS) {
        return NULL;
    }
    return terminal;
}

void GhosttyVTFreeTerminal(void *terminal) {
    if (terminal == NULL) { return; }
    ghostty_terminal_free((GhosttyTerminal)terminal);
}

void GhosttyVTResize(void *terminal, uint16_t cols, uint16_t rows) {
    if (terminal == NULL) { return; }
    ghostty_terminal_resize((GhosttyTerminal)terminal, cols, rows);
}

void GhosttyVTWrite(void *terminal, const uint8_t *bytes, size_t len) {
    if (terminal == NULL || bytes == NULL || len == 0) { return; }
    ghostty_terminal_vt_write((GhosttyTerminal)terminal, bytes, len);
}

void *GhosttyVTCreateFormatter(void *terminal) {
    if (terminal == NULL) { return NULL; }

    GhosttyFormatter formatter = NULL;
    GhosttyFormatterScreenExtra extraScreen = (GhosttyFormatterScreenExtra){
        .size = sizeof(GhosttyFormatterScreenExtra),
        .cursor = false,
        .style = true,
        .hyperlink = false,
        .protection = false,
        .kitty_keyboard = false,
        .charsets = false,
    };
    GhosttyFormatterTerminalExtra extraTerminal = (GhosttyFormatterTerminalExtra){
        .size = sizeof(GhosttyFormatterTerminalExtra),
        .palette = false,
        .modes = false,
        .scrolling_region = false,
        .tabstops = false,
        .pwd = false,
        .keyboard = false,
        .screen = extraScreen,
    };
    GhosttyFormatterTerminalOptions options = (GhosttyFormatterTerminalOptions){
        .size = sizeof(GhosttyFormatterTerminalOptions),
        // Emit VT sequences to preserve ANSI colors, styles, URLs, etc.
        .emit = GHOSTTY_FORMATTER_FORMAT_VT,
        .unwrap = false,
        .trim = false,
        .extra = extraTerminal,
    };

    GhosttyResult result = ghostty_formatter_terminal_new(NULL, &formatter, (GhosttyTerminal)terminal, options);
    if (result != GHOSTTY_SUCCESS) {
        return NULL;
    }
    return formatter;
}

void GhosttyVTFreeFormatter(void *formatter) {
    if (formatter == NULL) { return; }
    ghostty_formatter_free((GhosttyFormatter)formatter);
}

char *GhosttyVTFormatAlloc(void *formatter, size_t *outLen) {
    if (formatter == NULL || outLen == NULL) { return NULL; }
    uint8_t *outPtr = NULL;
    size_t len = 0;
    GhosttyResult result = ghostty_formatter_format_alloc((GhosttyFormatter)formatter, NULL, &outPtr, &len);
    if (result != GHOSTTY_SUCCESS || outPtr == NULL) {
        return NULL;
    }
    *outLen = len;
    return (char *)outPtr;
}

