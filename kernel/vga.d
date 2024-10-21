module vga;

import prim;
import util;
import bitfield;
import lowmem;
import bios;
import vm86;
import terminal;

align(0x200) struct VGAInfo
{
    align(1):
    char[4] signature;
    ubyte[2] vers;
    FarPtr!char oemName;
    uint cap;
    FarPtr!ushort modes;
    ushort totalMemory;
}

static assert(VGAInfo.signature.offsetof == 0x00);
static assert(VGAInfo.vers.offsetof == 0x04);
static assert(VGAInfo.oemName.offsetof == 0x06);
static assert(VGAInfo.cap.offsetof == 0x0A);
static assert(VGAInfo.modes.offsetof == 0x0E);
static assert(VGAInfo.totalMemory.offsetof == 0x12);
static assert(VGAInfo.sizeof == 0x200);

align(0x100) struct VGAModeInfo
{
    align(1):
    BitField!16 attr;
    ubyte[2] windowAttr;
    ushort windowGranularity;
    ushort windowSize;
    ushort[2] startSegment;
    FarPtr!void positioningFunc;
    ushort bytesPerScanLine;
    ushort width;
    ushort height;
    ubyte charWidth;
    ubyte charHeight;
    ubyte memoryPlaneCount;
    ubyte bitsPerPixel;
    ubyte bankCount;
    ubyte memoryModelType;
    ubyte bankSize;
    ubyte ramImagePageCount;
    ubyte reserved;
    ubyte[9] colourInfo;
    uint videoAddr;
}

uint getCursorPos()
{
    portOutputByte(0x3D4, 0x0F);
    uint low = portInput(0x3D5);
    portOutputByte(0x3D4, 0x0E);
    uint high = portInput(0x3D5);
    return low | (high << 8);
}

uint getCursorPosBios()
{
    BiosCall fn = {
        interrupt: 0x10,
        func: 0x03
    };
    fn();
    return fn.dh * 80 + fn.dl;
}

void setCursorPos(uint pos)
{
    portOutputByte(0x3D4, 0x0F);
    portOutputByte(0x3D5, cast(ubyte) pos);
    portOutputByte(0x3D4, 0x0E);
    portOutputByte(0x3D5, cast(ubyte) (pos >> 8));
}

void getVGAInfo(FarPtr!VGAInfo info)
{
    info.ptr.signature[0 .. 4] = "VBE2";
    BiosCall fn = {
        interrupt: 0x10,
        func: 0x4F,
        subfunc: 0x00,
        es: info.seg,
        di: info.off
    };
    fn();
}

void getVGAModeInfo(ushort mode, FarPtr!VGAModeInfo modeInfo)
{
    BiosCall fn = {
        interrupt: 0x10,
        func: 0x4F,
        subfunc: 0x01,
        cx: mode,
        es: modeInfo.seg,
        di: modeInfo.off
    };
    fn();
}
