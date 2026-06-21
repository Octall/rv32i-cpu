#!/usr/bin/env python3
# bin2hex.py <in.bin> <out.hex>
# Pack a flat binary into one little-endian 32-bit word per line ($readmemh format).
import sys
data = open(sys.argv[1], 'rb').read()
data += b'\x00' * ((-len(data)) % 4)          # pad to a whole word
with open(sys.argv[2], 'w') as f:
    for i in range(0, len(data), 4):
        w = data[i] | (data[i+1] << 8) | (data[i+2] << 16) | (data[i+3] << 24)
        f.write(f"{w:08x}\n")
