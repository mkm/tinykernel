module prim;

bool truth()
{
    return true;
}

T load(T)(T* addr)
{
    T result;
    static if (T.sizeof == 1)
    {
        asm
        {
            mov RDX, addr[RBP];
            mov AL, [RDX];
            mov result[RBP], AL;
        }
    }
    else static if (T.sizeof == 2)
    {
        asm
        {
            mov RDX, addr[RBP];
            mov AX, [RDX];
            mov result[RBP], AX;
        }
    }
    else static if (T.sizeof == 4)
    {
        asm
        {
            mov RDX, addr[RBP];
            mov EAX, [RDX];
            mov result[RBP], EAX;
        }
    }
    else
    {
        static assert(false);
    }
    return result;
}

void store(T)(T* addr, T value)
{
    static if (T.sizeof == 1)
    {
        asm
        {
            mov RDX, addr[RBP];
            mov AL, value[RBP];
            mov [RDX], AL;
        }
    }
    else static if (T.sizeof == 2)
    {
        asm
        {
            mov RDX, addr[RBP];
            mov AX, value[RBP];
            mov [RDX], AX;
        }
    }
    else static if (T.sizeof == 4)
    {
        asm
        {
            mov RDX, addr[RBP];
            mov EAX, value[RBP];
            mov [RDX], EAX;
        }
    }
    else
    {
        static assert(false);
    }
}

void pause()
{
    asm
    {
        naked;
        rep;
        nop;
        ret;
    }
}

void halt()
{
    asm
    {
        naked;
        hlt;
        ret;
    }
}

void intn(ubyte index)()
{
    asm
    {
        naked;
        int index;
        ret;
    }
}

ulong rdtsc()
{
    asm
    {
        naked;
        rdtsc;
        shl RDX, 32;
        or RAX, RDX;
        ret;
    }
}

ubyte portInput(ushort port)
{
    asm
    {
        naked;
        mov DX, DI;
        xor EAX, EAX;
        in AL, DX;
        ret;
    }
}

void portOutputByte(ushort port, ubyte value)
{
    asm
    {
        naked;
        mov DX, DI;
        mov AL, SIL;
        out DX, AL;
        ret;
    }
}

void portOutputWord(ushort port, ushort value)
{
    asm
    {
        naked;
        mov DX, DI;
        mov AX, SI;
        out DX, AX;
        ret;
    }
}

void sleep(ulong cycles)
{
    ulong count = rdtsc();
    while (rdtsc() < count + cycles)
    {
        pause();
    }
}

struct CPU
{
    @property static ulong cr3()
    {
        asm
        {
            naked;
            mov RAX, CR3;
            ret;
        }
    }

    @property static void cr3(ulong value)
    {
        asm
        {
            naked;
            mov CR3, RDI;
            ret;
        }
    }
}
