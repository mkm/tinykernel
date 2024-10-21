module lowmem;

import util;
import bitfield;
import bitarray;
import terminal;

__gshared LowMM lowMem;

enum size_t totalLowMemory = 1 << 19;
enum size_t totalLowBlocks = totalLowMemory >> 4;

struct LowMM
{
    BitArray inuse;

    this(size_t storage)
    {
        inuse.length = totalLowBlocks;
        inuse.ptr = cast(BitField!8*) storage;

        inuse[0x0000 .. 0x0040] = true; // Interrupt Vector Table
        inuse[0x0040 .. 0x0050] = true; // BIOS Data Area
        inuse[0x07C0 .. 0x5000] = true; // Kernel
        inuse[0x6000 .. 0x6700] = true; // Page Tables
        inuse[storage >> 4 .. storage + totalLowBlocks >> 4] = true; // This table
    }

    FarPtr!void allocRaw(size_t count)
    {
        count = aligned(0x10, count);
        auto bcount = count >> 4;

        size_t contiguous = 0;
        foreach (i; 0 .. inuse.length)
        {
            if (contiguous == bcount)
            {
                size_t start = i - bcount;
                inuse[start .. i] = true;
                return FarPtr!void(0, cast(ushort) start);
            }

            if (inuse[i])
            {
                contiguous = 0;
            }
            else
            {
                contiguous += 1;
            }
        }

        assert(false, "Out of memory");
    }

    FarPtr!T alloc(T)(size_t count = 1)
    {
        return cast(FarPtr!T) allocRaw(T.sizeof * count);
    }
}
