module physmem;

import traits;
import util;
import bitfield;
import lowmem;
import bios;
import terminal;

__gshared PhysMM pmm = void;

struct PhysAddr
{
    enum size_t base = 0xFFFF800000000000;

    size_t addr;

    static fromPtr(void* ptr)
    {
        return PhysAddr(cast(size_t) ptr - base);
    }

    @property void* ptr()
    {
        return cast(void*) (addr + base);
    }
}

@Derive("show")
struct MemRange
{
    enum Type : uint
    {
        Free = 1,
        Reserved = 2,
        ACPI = 3,
        NVS = 4
    }

    align(1):
    void* base;
    size_t length;
    Type type;
}
static assert(MemRange.sizeof == 20);

struct MemInfoQuery
{
    FarPtr!MemRange buffer;
    uint continuation;
    bool done;

    void reset()
    {
        buffer = lowMem.alloc!MemRange;
        continuation = 0;
        done = false;
    }

    bool next(ref MemRange range)
    {
        if (done)
        {
            return false;
        }

        BiosCall fn = {
            interrupt: 0x15,
            func: 0xE8,
            subfunc: 0x20,
            edx: 0x534D4150,
            ebx: continuation,
            cx: MemRange.sizeof,
            di: buffer.off,
            es: buffer.seg
        };
        fn();

        continuation = fn.ebx;
        if (continuation == 0)
        {
            done = true;
        }

        if (fn.carry)
        {
            return false;
        }
        else
        {
            range = *buffer;
            return true;
        }
    }
}

struct PhysMM
{
    alias Range = void[];

    struct PageState
    {
        enum Flag
        {
            Free,
            Usable
        }

        BitField!(Flag.max + 1) bits;

        @property bool free()
        {
            return bits[Flag.Free];
        }

        @property void free(bool value)
        {
            bits[Flag.Free] = value;
        }

        @property bool usable()
        {
            return bits[Flag.Usable];
        }

        @property void usable(bool value)
        {
            bits[Flag.Usable] = value;
        }

        @property static PageState unusable()
        {
            PageState state;
            state.free = false;
            state.usable = false;
            return state;
        }

        @property static PageState inUse()
        {
            PageState state;
            state.free = false;
            state.usable = true;
            return state;
        }

        @property static PageState freeForUse()
        {
            PageState state;
            state.free = true;
            state.usable = true;
            return state;
        }
    }

    Range[16] rangeBuffer;
    size_t rangeCount;
    PageState[] pages;

    void initRanges()
    {
        MemRange range;
        MemInfoQuery query;
        query.reset();
        while (query.next(range))
        {
            if (range.type == MemRange.Type.Free)
            {
                rangeBuffer[rangeCount] = range.base[0 .. range.length];
                rangeCount += 1;
            }
        }

        assert(rangeCount > 0);
    }

    @disable this();

    this(size_t kernelSize)
    {
        kernelSize = aligned(0x1000, kernelSize);
        initRanges();
        auto bound = cast(size_t) &ranges[$ - 1][$];
        auto pageCount = bound >> 12;
        if (pageCount * PageState.sizeof > 1.MiB)
        {
            pageCount = 1.MiB / PageState.sizeof;
        }
        size_t pagesStart = 0x100000 + kernelSize;
        pages = (cast(PageState*) pagesStart)[0 .. pageCount];

        pages[] = PageState.unusable;
        foreach (range; ranges)
        {
            auto addr = cast(size_t) range.ptr;
            if (cast(size_t) range.ptr >= 0x100000)
            {
                auto rangePageIndex = cast(size_t) range.ptr >> 12;
                auto rangePageCount = range.length >> 12;
                pages[rangePageIndex .. rangePageIndex + rangePageCount] = PageState.freeForUse;
            }
        }
        pages[0x100000 >> 12 .. pagesStart >> 12] = PageState.inUse;
        pages[pagesStart >> 12 .. pagesStart + aligned(0x1000, pageCount * PageState.sizeof) >> 12] = PageState.inUse;
    }

    @property Range[] ranges() return
    {
        return rangeBuffer[0 .. rangeCount];
    }

    PhysAddr alloc()
    {
        foreach (i, ref state; pages)
        {
            if (state.free && state.usable)
            {
                state.free = false;
                return PhysAddr(i * 0x1000);
            }
        }

        assert(false, "Out of memory");
    }

    PhysAddr allocZeroes()
    {
        auto addr = alloc();
        (cast(ubyte*) addr.ptr)[0 .. 0x1000] = 0;
        return addr;
    }

    void free(PhysAddr page)
    {
        auto index = page.addr >> 12;
        assert(!pages[index].free);
        pages[index].free = true;
    }
}
