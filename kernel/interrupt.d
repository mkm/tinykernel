module interrupt;

import bitfield;

__gshared IDTEntry[0x100] interruptHandlers;

enum GateType : ubyte
{
    Interrupt = 0xE,
    Trap = 0xF
}

struct IDTEntry
{
    align(1):
    ushort offset1;
    ushort segment;
    BitField!16 flags;
    ushort offset2;
    uint offset3;
    uint reserved;

    @property void* offset()
    {
        return cast(void*)
            (cast(size_t) offset1 |
             cast(size_t) offset2 << 16 |
             cast(size_t) offset3 << 32);
    }

    @property void offset(void* ptr)
    {
        auto addr = cast(size_t) ptr;
        offset1 = addr & 0xFFFF;
        offset2 = addr >> 16 & 0xFFFF;
        offset3 = addr >> 32;
    }

    @property GateType type()
    {
        return cast(GateType) flags[8 .. 12];
    }

    @property void type(GateType type)
    {
        flags[8 .. 12] = cast(ubyte) type;
    }

    @property bool present()
    {
        return flags[15];
    }

    @property void present(bool value)
    {
        flags[15] = value;
    }
}

static assert(IDTEntry.sizeof == 16);

alias IDT = IDTEntry[];

void loadIDT(IDT idt)
{
    IDTEntry* entries = idt.ptr;
    ushort size = cast(ushort) (idt.length * IDTEntry.sizeof - 1);
    asm
    {
        jmp code;
    idtr:
        dq 0;
        dw 0;
    code:
        lea RDX, [idtr];
        mov AX, RBP[size];
        mov [RDX + 0], AX;
        mov RAX, RBP[entries];
        mov [RDX + 2], RAX;
        lidt [RDX];
    }
}

void setupHandler(int index)()
{
    void* handler;
    enum digit0 = 0x7400 | cast(ushort) '0' + (index / 100);
    enum digit1 = 0x7400 | cast(ushort) '0' + ((index / 10) % 10);
    enum digit2 = 0x7400 | cast(ushort) '0' + (index % 10);
    asm
    {
        jmp storePtr;
    handle:
        mov RDX, 0xB8000;
        mov word ptr [RDX + 0], 0x7449; // I
        mov word ptr [RDX + 2], 0x744E; // N
        mov word ptr [RDX + 4], 0x7454; // T
        mov word ptr [RDX + 6], 0x7420;
        mov word ptr [RDX + 8], digit0;
        mov word ptr [RDX + 10], digit1;
        mov word ptr [RDX + 12], digit2;
        mov word ptr [RDX + 14], 0x7420;
    loop:
        hlt;
        jmp loop;
    storePtr:
        lea RDX, [handle];
        mov RBP[handler], RDX;
    }
    auto entry = &interruptHandlers[index];
    entry.segment = 0x08;
    entry.offset = handler;
    entry.present = true;
    entry.type = GateType.Trap;
}

void setupIDT()
{
    static foreach (i; 0 .. interruptHandlers.length)
    {
        setupHandler!i();
    }

    loadIDT(interruptHandlers);
}
