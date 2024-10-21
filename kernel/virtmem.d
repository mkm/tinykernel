module virtmem;

import prim;
import util;
import bitfield;
import physmem;
import terminal;

__gshared VirtMM vmm = void;

struct VirtAddr
{
    BitField!64 ptr;

    this(size_t ptr)
    {
        this.ptr = BitField!64(ptr);
    }

    size_t opIndex(int level)
    in(1 <= level && level <= 4)
    {
        return ptr[3 + level * 9 .. 12 + level * 9];
    }
}

struct PageTable(int level)
{
    static assert(1 <= level && level <= 4);
    static assert(Entry.sizeof == 8);

    struct Entry
    {
        BitField!64 data;

        @property bool present()
        {
            return data[0];
        }

        @property void present(bool value)
        {
            data[0] = value;
        }

        static if (2 <= level && level <= 3)
        {
            @property bool large()
            {
                return data[7];
            }

            @property void large(bool value)
            {
                data[7] = value;
            }
        }

        @property PhysAddr addr()
        {
            return PhysAddr(data[12 .. 52] << 12);
        }

        @property void addr(PhysAddr value)
        {
            data[12 .. 52] = value.addr >> 12;
        }

        @property uint ext()
        {
            return cast(uint) (data[52 .. 59] << 3 | data[9 .. 12]);
        }

        @property void ext(uint value)
        {
            data[9 .. 12] = value & 0x7;
            data[52 .. 59] = value >> 3;
        }

        static if (2 <= level && level <= 4)
        {
            @property PageTable!(level - 1)* child()
            {
                return cast(PageTable!(level - 1)*) addr.ptr;
            }
        }
    }

    Entry[0x200] entries;
}

static foreach (level; [1, 2, 3, 4])
{
    static assert(PageTable!level.sizeof == 0x1000);
}

struct VirtMM
{
    PageTable!4* root;
    PageTable!3* heap;
    VirtAddr nextPage;

    @disable this();

    this(Construct)
    {
        root = cast(PageTable!4*) pmm.allocZeroes().ptr;

        auto lowTableDir = cast(PageTable!3*) pmm.allocZeroes().ptr;
        auto lowTable = cast(PageTable!2*) pmm.allocZeroes().ptr;
        root.entries[0].addr = PhysAddr.fromPtr(lowTableDir);
        root.entries[0].present = true;
        lowTableDir.entries[0].addr = PhysAddr.fromPtr(lowTable);
        lowTableDir.entries[0].present = true;
        lowTable.entries[0].addr = PhysAddr(0);
        lowTable.entries[0].large = true;
        lowTable.entries[0].present = true;

        auto linearTable = cast(PageTable!3*) pmm.allocZeroes().ptr;
        root.entries[0x100].addr = PhysAddr.fromPtr(linearTable);
        root.entries[0x100].present = true;
        foreach (index, ref entry; linearTable.entries)
        {
            entry.addr = PhysAddr(index * 1.GiB);
            entry.large = true;
            entry.present = true;
        }

        heap = cast(PageTable!3*) pmm.allocZeroes().ptr;
        root.entries[0x180].addr = PhysAddr.fromPtr(heap);
        root.entries[0x180].present = true;
        nextPage = 0xFFFFC00000000000;

        CPU.cr3 = PhysAddr.fromPtr(root).addr;
    }

    void* allocNext()
    {
        void* result = cast(void*) nextPage.ptr.bits;
        assert(nextPage[4] == 0x180);
        auto entry3 = &heap.entries[nextPage[3]];
        if (!entry3.present)
        {
            entry3.addr = pmm.allocZeroes();
            entry3.present = true;
        }
        auto entry2 = &entry3.child.entries[nextPage[2]];
        if (!entry2.present)
        {
            entry2.addr = pmm.allocZeroes();
            entry2.present = true;
        }
        auto entry1 = &entry2.child.entries[nextPage[1]];
        assert(!entry1.present);
        auto pAddr = pmm.alloc();
        entry1.addr = pAddr;
        entry1.present = true;
        nextPage = VirtAddr(nextPage.ptr.bits + 0x1000);
        return result;
    }

    void* alloc(size_t count)
    {
        if (count == 0)
        {
            return null;
        }

        void* ptr = allocNext();
        foreach (i; 1 .. count)
        {
            allocNext();
        }
        return ptr;
    }
}
