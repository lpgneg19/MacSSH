#ifndef GHOSTTY_VT_BRIDGE_H
#define GHOSTTY_VT_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void *GhosttyVTCreateTerminal(uint16_t cols, uint16_t rows, size_t scrollback);
void GhosttyVTFreeTerminal(void *terminal);
void GhosttyVTResize(void *terminal, uint16_t cols, uint16_t rows);
void GhosttyVTWrite(void *terminal, const uint8_t *bytes, size_t len);

void *GhosttyVTCreateFormatter(void *terminal);
void GhosttyVTFreeFormatter(void *formatter);
char *GhosttyVTFormatAlloc(void *formatter, size_t *outLen);

#ifdef __cplusplus
}
#endif

#endif /* GHOSTTY_VT_BRIDGE_H */
