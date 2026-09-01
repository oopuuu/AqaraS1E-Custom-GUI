#!/usr/bin/env python3
"""
S1E 480x480 Ultra-Fast Streaming Animation (.anim) Generator & Converter
Container Format:
  [Header: 14 Bytes]
    'A''N''I''M' (4B)
    Width        (2B, uint16_le)
    Height       (2B, uint16_le)
    FPS          (2B, uint16_le)
    TotalFrames  (4B, uint32_le)
  Followed by each frame:
    ChunkLength  (4B, uint32_le)
    QOI Frame Data (ChunkLength Bytes)
"""

import struct, math, os, sys

def encode_qoi(width, height, pixels):
    """Encodes 480x480 RGBA bytearray into standard QOI binary stream"""
    out = bytearray(b"qoif")
    out += struct.pack(">IIBB", width, height, 4, 0)
    
    index = [(0, 0, 0, 0)] * 64
    px_prev = (0, 0, 0, 255)
    run = 0
    
    total_px = width * height
    for i in range(total_px):
        offset = i * 4
        px = (pixels[offset], pixels[offset+1], pixels[offset+2], pixels[offset+3])
        
        if px == px_prev:
            run += 1
            if run == 62 or i == total_px - 1:
                out.append(0xc0 | (run - 1))
                run = 0
        else:
            if run > 0:
                out.append(0xc0 | (run - 1))
                run = 0
                
            idx = (px[0] * 3 + px[1] * 5 + px[2] * 7 + px[3] * 11) % 64
            if index[idx] == px:
                out.append(idx)
            elif px[3] == px_prev[3]: # Same alpha
                vr = (px[0] - px_prev[0]) & 0xff
                vg = (px[1] - px_prev[1]) & 0xff
                vb = (px[2] - px_prev[2]) & 0xff
                
                vr = vr if vr < 128 else vr - 256
                vg = vg if vg < 128 else vg - 256
                vb = vb if vb < 128 else vb - 256
                
                vg_r = vr - vg
                vg_b = vb - vg
                
                if -2 <= vr <= 1 and -2 <= vg <= 1 and -2 <= vb <= 1:
                    out.append(0x40 | ((vr + 2) << 4) | ((vg + 2) << 2) | (vb + 2))
                elif -32 <= vg <= 31 and -8 <= vg_r <= 7 and -8 <= vg_b <= 7:
                    out.append(0x80 | (vg + 32))
                    out.append(((vg_r + 8) << 4) | (vg_b + 8))
                else:
                    out.append(0xfe)
                    out.extend([px[0], px[1], px[2]])
            else:
                out.append(0xff)
                out.extend([px[0], px[1], px[2], px[3]])
                
            index[idx] = px
            px_prev = px
            
    if run > 0:
        out.append(0xc0 | (run - 1))
        
    out.extend(b"\x00\x00\x00\x00\x00\x00\x00\x01")
    return bytes(out)

def write_anim(out_path, width, height, fps, frames):
    total_frames = len(frames)
    with open(out_path, "wb") as f:
        # 14 bytes header:
        # 'ANIM' (4B)
        f.write(b"ANIM")
        # w (2B little-endian), h (2B little-endian), fps (2B little-endian), total_frames (4B little-endian)
        f.write(struct.pack("<HHHI", width, height, fps, total_frames))
        
        for idx, frame_rgba in enumerate(frames):
            qoi = encode_qoi(width, height, frame_rgba)
            chunk_len = len(qoi)
            f.write(struct.pack("<I", chunk_len))
            f.write(qoi)
            if (idx + 1) % 15 == 0 or idx == total_frames - 1:
                print(f"  Frame {idx+1}/{total_frames} encoded (QOI chunk: {chunk_len}B)")
                
    sz = os.path.getsize(out_path)
    print(f"Done! {out_path}: {sz} bytes ({sz/1024:.1f} KB, {sz/1024/1024:.2f} MB)")

if __name__ == "__main__":
    print("S1E Animation Tool Ready.")
