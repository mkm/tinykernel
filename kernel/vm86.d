module vm86;

import prim;
import traits;
// import terminal;
import format : format;
import buffer;
import terminal : panic;

union Reg
{
    uint ereg;
    ushort reg;
    struct
    {
        ubyte low;
        ubyte high;
    }
}

enum
{
    AX,
    CX,
    DX,
    BX,
    SP,
    BP,
    SI,
    DI
}

string regName(T)(int r)
{
    static if (is(T == ubyte))
    {
        switch (r)
        {
            case 0:
                return "al";
            case 1:
                return "cl";
            case 2:
                return "dl";
            case 3:
                return "bl";
            case 4:
                return "ah";
            case 5:
                return "ch";
            case 6:
                return "dh";
            case 7:
                return "bh";
            default:
                panic!("regName8 ~n")(r);
        }
    }
    else static if (is(T == ushort))
    {
        switch (r)
        {
            case 0:
                return "ax";
            case 1:
                return "cx";
            case 2:
                return "dx";
            case 3:
                return "bx";
            case 4:
                return "sp";
            case 5:
                return "bp";
            case 6:
                return "si";
            case 7:
                return "di";
            default:
                panic!("regName16 ~n")(r);
        }
    }
    else
    {
        static assert(is(T == uint));
        switch (r)
        {
            case 0:
                return "eax";
            case 1:
                return "ecx";
            case 2:
                return "edx";
            case 3:
                return "ebx";
            case 4:
                return "esp";
            case 5:
                return "ebp";
            case 6:
                return "esi";
            case 7:
                return "edi";
            default:
                panic!("regName32 ~n")(r);
        }
    }
}

enum
{
    ES,
    CS,
    SS,
    DS,
    FS,
    GS,
    ZS
}

string segName(int s)
{
    switch (s)
    {
        case ES:
            return "es";
        case CS:
            return "cs";
        case SS:
            return "ss";
        case DS:
            return "ds";
        case FS:
            return "fs";
        case GS:
            return "gs";
        default:
            panic!("segName ~n")(s);
    }
}

enum Rep
{
    None,
    Z,
    NZ
}

struct ModRM
{
    ubyte value;

    @property mod() const
    {
        return value >> 6;
    }

    @property reg() const
    {
        return (value >> 3) & 0b111;
    }

    @property rm() const
    {
        return value & 0b111;
    }
}

struct SIB
{
    ubyte value;

    @property scale()
    {
        return 1 << (value >> 6);
    }

    @property index()
    {
        return (value >> 3) & 0b111;
    }

    @property base()
    {
        return value & 0b111;
    }
}

struct Flags
{
    union
    {
        uint ereg;
        ushort reg;
    }

    static char flagName(int n)
    {
        switch (n)
        {
            case 0:
                return 'c';
            case 2:
                return 'p';
            case 4:
                return 'a';
            case 6:
                return 'z';
            case 7:
                return 's';
            case 11:
                return 'o';
            default:
                return '?';
        }
    }

    bool opIndex(int n) const
    {
        return (ereg >> n) & 1;
    }

    void opIndexAssign(bool value, int n)
    {
        ereg &= ~(1 << n);
        ereg |= cast(uint) value << n;
    }

    @property bool c() const
    {
        return this[0];
    }

    @property void c(bool value)
    {
        this[0] = value;
    }

    @property bool p() const
    {
        return this[2];
    }

    @property void p(bool value)
    {
        this[2] = value;
    }

    @property bool a() const
    {
        return this[4];
    }

    @property void a(bool value)
    {
        this[4] = value;
    }

    @property bool z() const
    {
        return this[6];
    }

    @property z(bool value)
    {
        this[6] = value;
    }

    @property bool s() const
    {
        return this[7];
    }

    @property s(bool value)
    {
        this[7] = value;
    }

    @property bool o() const
    {
        return this[11];
    }

    @property o(bool value)
    {
        this[11] = value;
    }

    void show(char mod)(ref Buffer term) const
    {
        foreach (i; 0 .. 12)
        {
            if (this[i])
            {
                term.write(flagName(i));
            }
            else
            {
                term.write('-');
            }
        }
    }
}

struct ShowRM(T)
{
    ModRM modrm;
    void* loadAddr;

    void show(char mod)(ref Buffer term) const
    {
        if (modrm.mod == 0b11)
        {
            term.write(regName!T(modrm.rm));
        }
        else
        {
            format!("[~p]")(term, loadAddr);
        }
    }
}

struct VM
{
    Reg[8] gp;
    ushort[7] seg;
    Flags flags;
    Reg ip;

    debug
    {
        Buffer* console;
        void* loadAddr;
        uint loadValue;
        uint storeValue;
        void log(string fmt, T...)(T args)
        {
            if (console)
            {
                format!(fmt)(*console, args);
            }
        }

        ShowRM!T mkShowRM(T)(ModRM modrm)
        {
            return ShowRM!T(modrm, loadAddr);
        }
    }

    T* regp(T)(int r) scope return
    {
        static if (is(T == ubyte))
        {
            if ((r & 0x4) == 0)
            {
                return &gp[r].low;
            }
            else
            {
                return &gp[r & 0x3].high;
            }
        }
        else static if (is(T == ushort))
        {
            return &gp[r].reg;
        }
        else
        {
            static assert(is(T == uint));
            return &gp[r].ereg;
        }
    }

    ubyte getOp()
    {
        ubyte op = load(cast(ubyte*)(seg[CS] * 0x10 + ip.reg));
        ip.ereg += 1;
        return op;
    }

    T getImm(T)()
    {
        T imm = load(cast(T*) (seg[CS] * 0x10 + ip.reg));
        ip.ereg += T.sizeof;
        return imm;
    }

    ModRM getModRM()
    {
        return ModRM(getOp());
    }

    SIB getSIB()
    {
        return SIB(getOp());
    }

    T* resolveRM(T, A)(int s, ModRM modrm) scope return
    {
        switch (modrm.mod)
        {
            case 0b00:
                static if (is(A == ushort))
                {
                    switch (modrm.rm)
                    {
                        case 0: // bx + si
                            ushort addr = cast(ushort) (gp[BX].reg + gp[SI].reg);
                            return cast(T*) (seg[s] * 0x10 + addr);
                        case 6: // disp16
                            ushort addr = getImm!ushort;
                            return cast(T*) (seg[s] * 0x10 + addr);
                        default:
                            panic!("resolveRM16/00/~n")(modrm.rm);
                    }
                }
                else
                {
                    static assert(is(A == uint));
                    switch (modrm.rm)
                    {
                        case 4: // SIB
                            panic!("resolveRM32/00/SIB");
                        case 5: // eip + disp32
                            panic!("resolveRM32/00/5");
                        default:
                            return cast(T*) (seg[s] * 0x10 + gp[modrm.rm].ereg);
                    }
                }
            case 0b01:
                static if (is(A == ushort))
                {
                    switch (modrm.rm)
                    {
                        case 6:
                            auto disp = cast(byte) getImm!ubyte;
                            return cast(T*) (seg[s] * 0x10 + gp[BP].reg + disp);
                        default:
                            panic!("resolveRM16/01/~n")(modrm.rm);
                    }
                }
                else
                {
                    static assert(is(A == uint));
                    if (modrm.rm == 4) // SIB + disp8
                    {
                        auto sib = getSIB();
                        auto disp = getImm!ubyte;
                        return cast(T*) (seg[s] * 0x10 + gp[sib.base].ereg + sib.scale * gp[sib.index].ereg + disp);
                    }
                    else
                    {
                        byte disp = cast(byte) getImm!ubyte;
                        return cast(T*) (seg[s] * 0x10 + gp[modrm.rm].ereg + disp);
                    }
                }
            case 0b10:
                static if (is(A == ushort))
                {
                    switch (modrm.rm)
                    {
                        case 6:
                            auto disp = cast(short) getImm!ushort;
                            return cast(T*) (seg[s] * 0x10 + gp[BP].reg + disp);
                        default:
                            panic!("resolveRM16/01/~n")(modrm.rm);
                    }
                }
                else
                {
                    static assert(is(A == uint));
                    if (modrm.rm == 4) // SIB + disp32
                    {
                        auto sib = getSIB();
                        auto disp = getImm!uint;
                        return cast(T*) (seg[s] * 0x10 + gp[sib.base].ereg + sib.scale * gp[sib.index].ereg + disp);
                    }
                    else
                    {
                        int disp = cast(int) getImm!uint;
                        return cast(T*) (seg[s] * 0x10 + gp[modrm.rm].ereg + disp);
                    }
                }
            case 0b11:
                return regp!(T)(modrm.rm);
            default:
                panic!("resolveRM/~n")(modrm.mod);
        }
    }

    T loadRM(T, A)(int s, ModRM modrm)
    {
        T* addr = resolveRM!(T, A)(s, modrm);
        debug loadAddr = addr;
        debug loadValue = load(addr);
        return load(addr);
    }

    void storeRM(T, A)(int s, ModRM modrm, T value)
    {
        T* addr = resolveRM!(T, A)(s, modrm);
        debug loadAddr = addr;
        debug storeValue = value;
        store(addr, value);
    }

    T effAddrRM(T, A)(ModRM modrm)
    {
        auto addr = cast(ushort) resolveRM!(T, A)(ZS, modrm);
        debug loadAddr = cast(void*) addr;
        return cast(T) addr;
    }

    T and(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov AL, arg2[RBP];
                and arg1[RBP], AL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                and arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                and arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = false;
        flags.p = status.p;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = false;
        return arg1;
    }

    T or(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov AL, arg2[RBP];
                or arg1[RBP], AL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                or arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                or arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = false;
        flags.p = status.p;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = false;
        return arg1;
    }

    T xor(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov AL, arg2[RBP];
                xor arg1[RBP], AL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                xor arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                xor arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = false;
        flags.p = status.p;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = false;
        return arg1;
    }

    T shl(T)(T arg1, ubyte arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov CL, arg2[RBP];
                shl arg1[RBP], CL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov CL, arg2[RBP];
                shl arg1[RBP], CL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov CL, arg2[RBP];
                shl arg1[RBP], CL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = status.c;
        flags.p = status.p;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = status.o;
        flags.a = status.a;
        return arg1;
    }

    T shr(T)(T arg1, ubyte arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov CL, arg2[RBP];
                shr arg1[RBP], CL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov CL, arg2[RBP];
                shr arg1[RBP], CL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov CL, arg2[RBP];
                shr arg1[RBP], CL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = status.c;
        flags.p = status.p;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = status.o;
        flags.a = status.a;
        return arg1;
    }

    T add(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov AL, arg2[RBP];
                add arg1[RBP], AL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                add arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                add arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = status.c;
        flags.p = status.p;
        flags.a = status.a;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = status.o;
        return arg1;
    }

    T sub(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov AL, arg2[RBP];
                sub arg1[RBP], AL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                sub arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                sub arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = status.c;
        flags.p = status.p;
        flags.a = status.a;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = status.o;
        return arg1;
    }

    T sbb(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov AL, arg2[RBP];
                sbb arg1[RBP], AL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                sbb arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                sbb arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = status.c;
        flags.p = status.p;
        flags.a = status.a;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = status.o;
        return arg1;
    }

    T inc(T)(T arg)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                inc arg[RBP];
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                inc arg[RBP];
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                inc arg[RBP];
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.p = status.p;
        flags.a = status.a;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = status.o;
        return arg;
    }

    T dec(T)(T arg)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                dec arg[RBP];
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                dec arg[RBP];
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                dec arg[RBP];
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.p = status.p;
        flags.a = status.a;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = status.o;
        return arg;
    }

    T imul(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                imul AX, arg1[RBP];
                mov arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                imul EAX, arg1[RBP];
                mov arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = status.c;
        flags.o = status.o;
        return arg1;
    }

    T[2] div(T)(T low, T high, T arg)
    {
        Flags status;
        static if (is(T == ushort))
        {
            asm
            {
                mov AX, low[RBP];
                mov DX, high[RBP];
                div arg[RBP];
                mov low[RBP], AX;
                mov high[RBP], DX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, low[RBP];
                mov EDX, high[RBP];
                div arg[RBP];
                mov low[RBP], EAX;
                mov high[RBP], EDX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        return [low, high];
    }

    T[2] idiv(T)(T low, T high, T arg)
    {
        Flags status;
        static if (is(T == ushort))
        {
            asm
            {
                mov AX, low[RBP];
                mov DX, high[RBP];
                idiv arg[RBP];
                mov low[RBP], AX;
                mov high[RBP], DX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, low[RBP];
                mov EDX, high[RBP];
                idiv arg[RBP];
                mov low[RBP], EAX;
                mov high[RBP], EDX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        return [low, high];
    }

    void test(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov AL, arg2[RBP];
                test arg1[RBP], AL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                test arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                test arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = false;
        flags.p = status.p;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = false;
    }

    void cmp(T)(T arg1, T arg2)
    {
        Flags status;
        static if (is(T == ubyte))
        {
            asm
            {
                mov AL, arg2[RBP];
                cmp arg1[RBP], AL;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else static if (is(T == ushort))
        {
            asm
            {
                mov AX, arg2[RBP];
                cmp arg1[RBP], AX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }
        else
        {
            static assert(is(T == uint));
            asm
            {
                mov EAX, arg2[RBP];
                cmp arg1[RBP], EAX;
                pushfq;
                pop RAX;
                mov status[RBP], EAX;
            }
        }

        flags.c = status.c;
        flags.p = status.p;
        flags.a = status.a;
        flags.z = status.z;
        flags.s = status.s;
        flags.o = status.o;
    }

    T signExtend(T, U)(U value)
    {
        return cast(T) cast(asSigned!T) cast(asSigned!U) value;
    }

    void push(T)(T value)
    {
        gp[SP].reg -= T.sizeof;
        T* ptr = cast(T*) (seg[SS] * 0x10 + gp[SP].reg);
        store(ptr, value);
    }

    T pop(T)()
    {
        T* ptr = cast(T*) (seg[SS] * 0x10 + gp[SP].reg);
        T val = load(ptr);
        gp[SP].reg += T.sizeof;
        return val;
    }

    bool condValue(int cond)
    {
        switch (cond)
        {
            case 0:
                return flags.o;
            case 1:
                return flags.c;
            case 2:
                return flags.z;
            case 3:
                return flags.c || flags.z;
            case 4:
                return flags.s;
            case 5:
                return flags.p;
            case 6:
                return flags.s != flags.o;
            case 7:
                return flags.z || flags.s != flags.o;
            default:
                panic!("condValue(~n)\n")(cond);
        }
    }

    string condName(int cond)
    {
        switch (cond)
        {
            case 0:
                return "o";
            case 1:
                return "b";
            case 2:
                return "e";
            case 3:
                return "be";
            case 4:
                return "s";
            case 5:
                return "p";
            case 6:
                return "l";
            case 7:
                return "le";
            default:
                panic!("condName(~n)\n")(cond);
        }
    }

    bool genericOp(T, A, string name, alias op)(int mode, int dataSeg)
    {
        switch (mode)
        {
            case 0: // op rm8, reg
                auto modrm = getModRM();
                auto addr = resolveRM!(ubyte, A)(dataSeg, modrm);
                auto arg1 = *addr;
                auto arg2 = *regp!ubyte(modrm.reg);
                *addr = op(&this, arg1, arg2);
                debug log!("`" ~ name ~ "` ~x@~s, ~x@~s\n")(arg1, mkShowRM!ubyte(modrm), arg2, regName!ubyte(modrm.reg));
                return true;
            case 1: // op rm, reg
                auto modrm = getModRM();
                auto addr = resolveRM!(T, A)(dataSeg, modrm);
                auto arg1 = *addr;
                auto arg2 = *regp!T(modrm.reg);
                *addr = op(&this, arg1, arg2);
                debug log!("`" ~ name ~ "` ~x@~s, ~x@~s\n")(arg1, mkShowRM!T(modrm), arg2, regName!T(modrm.reg));
                return true;
            case 4: // op al, imm8
                auto arg1 = gp[AX].low;
                auto arg2 = getImm!ubyte;
                gp[AX].low = op(&this, arg1, arg2);
                debug log!("`" ~ name ~ "` ~x@al, ~x\n")(arg1, arg2);
                return true;
            case 5: // op ax, imm
                auto arg1 = *regp!T(AX);
                auto arg2 = getImm!T;
                *regp!T(AX) = op(&this, arg1, arg2);
                debug log!("`" ~ name ~ "` ~x@~s, ~x\n")(arg1, regName!T(AX), arg2);
                return true;
            default:
                return false;
        }
    }

    bool next(T, A)(int dataSeg, Rep rep)
    {
        ubyte op = getOp();
        switch (op)
        {
            case 0x00: .. case 0x07: // add
                static U fn(U)(VM* vm, U arg1, U arg2)
                {
                    return vm.add(arg1, arg2);
                }
                return genericOp!(T, A, "add", fn)(op - 0x00, dataSeg);
            case 0x08: .. case 0x0D: // or
                static U fn(U)(VM* vm, U arg1, U arg2)
                {
                    return vm.or(arg1, arg2);
                }
                return genericOp!(T, A, "or", fn)(op - 0x08, dataSeg);
            case 0x0F: // two-byte opcodes
                ubyte fop = getOp();
                switch (fop)
                {
                    /*case 0x84: // jz/je
                        auto offset = cast(short) getImm!ushort;
                        if (flags.z)
                        {
                            ip.reg += offset;
                            debug log!("jz ~x -> ~x\n")(offset, ip.reg);
                        }
                        else
                        {
                            debug log!("jz ~x\n")(offset);
                        }
                        return true;*/
                    case 0x80: .. case 0x8F: // jcc rel
                        auto offset = cast(asSigned!T) getImm!T;
                        bool invert = (fop & 1) == 1;
                        int cc = (fop - 0x80) >> 1;
                        if (condValue(cc) != invert)
                        {
                            ip.reg += offset;
                            debug log!("j~s~s ~x -> ~x\n")(invert ? "n" : "", condName(cc), offset, ip.reg);
                        }
                        else
                        {
                            debug log!("j~s~s ~x\n")(invert ? "n" : "", condName(cc), offset);
                        }
                        return true;
                        /*auto offset = cast(short) getImm!ushort;
                        if (!flags.z)
                        {
                            ip.reg += offset;
                            debug log!("jnz ~x -> ~x\n")(offset, ip.reg);
                        }
                        else
                        {
                            debug log!("jnz ~x\n")(offset);
                        }
                        return true;*/
                    case 0x90: .. case 0x9F: // setcc
                        auto modrm = getModRM();
                        switch (modrm.reg)
                        {
                            case 0:
                                bool invert = (fop & 1) == 1;
                                int cc = (fop - 0x90) >> 1;
                                ubyte value = condValue(cc) != invert;
                                storeRM!(ubyte, A)(dataSeg, modrm, value);
                                debug log!("set~s~s ~b!~s\n")(invert ? "n" : "", condName(cc), value, mkShowRM!ubyte(modrm));
                                return true;
                            default:
                                panic!("0x90/~n")(modrm.reg);
                        }
                    case 0xAF: // imul reg, rm
                        auto modrm = getModRM();
                        auto arg1 = *regp!T(modrm.reg);
                        auto arg2 = loadRM!(T, A)(dataSeg, modrm);
                        *regp!T(modrm.reg) = imul(arg1, arg2);
                        debug log!("imul ~x@~s, ~x@~s\n")(arg1, regName!T(modrm.reg), arg2, mkShowRM!T(modrm));
                        return true;
                    case 0xB6: // movzx reg, rm8
                        auto modrm = getModRM();
                        *regp!T(modrm.reg) = cast(T) loadRM!(ubyte, A)(dataSeg, modrm);
                        debug log!("movzx ~s, ~x@~s\n")(regName!T(modrm.reg), loadValue, mkShowRM!ubyte(modrm));
                        return true;
                    case 0xB7: // movzx reg, rm
                        auto modrm = getModRM();
                        *regp!T(modrm.reg) = cast(T) loadRM!(ushort, A)(dataSeg, modrm);
                        debug log!("movzx ~s, ~x@~s\n")(regName!T(modrm.reg), loadValue, mkShowRM!ushort(modrm));
                        return true;
                    case 0xBE: // movsx reg, rm8
                        auto modrm = getModRM();
                        auto arg = loadRM!(ubyte, A)(dataSeg, modrm);
                        *regp!T(modrm.reg) = signExtend!T(arg);
                        debug log!("movsx ~s, ~x@~s\n")(regName!T(modrm.reg), arg, mkShowRM!ubyte(modrm));
                        return true;
                    default:
                        return false;
                }
            case 0x1E: // push ds
                push!ushort(seg[DS]);
                debug log!("`push` ds\n");
                return true;
            case 0x20: .. case 0x25: // and
                static U fn(U)(VM* vm, U arg1, U arg2)
                {
                    return vm.and(arg1, arg2);
                }
                return genericOp!(T, A, "and", fn)(op - 0x20, dataSeg);
            case 0x26: // es:
                debug log!("es: ");
                return next!(T, A)(ES, rep);
            case 0x28: .. case 0x2D: // sub
                static U fn(U)(VM* vm, U arg1, U arg2)
                {
                    return vm.sub(arg1, arg2);
                }
                return genericOp!(T, A, "sub", fn)(op - 0x28, dataSeg);
            case 0x2E: // cs:
                debug log!("cs: ");
                return next!(T, A)(CS, rep);
            case 0x30: .. case 0x35:
                static U fn(U)(VM* vm, U arg1, U arg2)
                {
                    return vm.xor(arg1, arg2);
                }
                return genericOp!(T, A, "xor", fn)(op - 0x30, dataSeg);
            case 0x38: .. case 0x3D:
                static U fn(U)(VM* vm, U arg1, U arg2)
                {
                    vm.cmp(arg1, arg2);
                    return arg1;
                }
                return genericOp!(T, A, "cmp", fn)(op - 0x38, dataSeg);
            case 0x40: .. case 0x47: // inc reg
                int reg = op - 0x40;
                auto arg = *regp!T(reg);
                *regp!T(reg) = inc(arg);
                debug log!("inc ~x@~s\n")(arg, regName!T(reg));
                return true;
            case 0x48: .. case 0x4F: // dec reg
                int reg = op - 0x48;
                auto arg = *regp!T(reg);
                *regp!T(reg) = dec(arg);
                debug log!("dec ~x@~s\n")(arg, regName!T(reg));
                return true;
            case 0x50: .. case 0x57: // push reg
                int reg = op - 0x50;
                auto value = *regp!T(reg);
                push!T(value);
                debug log!("`push` ~x@~s\n")(value, regName!T(reg));
                return true;
            case 0x58: .. case 0x5F: // pop reg
                int reg = op - 0x58;
                *regp!T(reg) = pop!T;
                debug log!("`pop` ~s\n")(regName!T(reg));
                return true;
            case 0x66: // operand size override
                return next!(uint, A)(dataSeg, rep);
            case 0x67: // address size override
                return next!(T, uint)(dataSeg, rep);
            case 0x68: // push imm
                auto imm = getImm!T;
                push!T(imm);
                debug log!("`push` ~x\n")(imm);
                return true;
            case 0x6B: // imul reg, rm, imm8
                auto modrm = getModRM();
                auto arg1 = loadRM!(T, A)(dataSeg, modrm);
                auto arg2 = getImm!ubyte;
                auto value = imul(arg1, arg2);
                *regp!T(modrm.reg) = value;
                debug log!("imul ~x!~s, ~x@~s, ~x\n")(value, regName!T(modrm.reg), arg1, mkShowRM!T(modrm), arg2);
                return true;
            case 0x70: .. case 0x7F: // jcc rel8
                auto offset = cast(byte) getImm!ubyte;
                bool invert = (op & 1) == 1;
                int cc = (op - 0x70) >> 1;
                if (condValue(cc) != invert)
                {
                    ip.reg += offset;
                    debug log!("j~s~s ~x -> ~x\n")(invert ? "n" : "", condName(cc), offset, ip.reg);
                }
                else
                {
                    debug log!("j~s~s ~x\n")(invert ? "n" : "", condName(cc), offset);
                }
                return true;
            case 0x80:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 3: // sbb rm8, imm8
                        auto addr = resolveRM!(ubyte, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = getImm!ubyte;
                        *addr = sbb(arg1, arg2);
                        debug log!("sbb ~x@~s, ~x\n")(arg1, mkShowRM!ubyte(modrm), arg2);
                        return true;
                    case 4: // and rm8, imm8
                        auto addr = resolveRM!(ubyte, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = getImm!ubyte;
                        *addr = and(arg1, arg2);
                        debug log!("and ~x@~s, ~x\n")(arg1, mkShowRM!ubyte(modrm), arg2);
                        return true;
                    case 7: // cmp rm8, imm8
                        auto arg1 = loadRM!(ubyte, A)(dataSeg, modrm);
                        auto arg2 = getImm!ubyte;
                        cmp(arg1, arg2);
                        debug log!("cmp ~x@~s, ~x\n")(loadValue, mkShowRM!ubyte(modrm), arg2);
                        return true;
                    default:
                        panic!("0x80/~n")(modrm.reg);
                }
            case 0x81:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 0: // add rm, imm
                        auto addr = resolveRM!(T, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = getImm!T;
                        *addr = add(arg1, arg2);
                        debug log!("add ~x@~s, ~x\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    case 4: // and rm, imm
                        auto addr = resolveRM!(T, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = getImm!T;
                        *addr = and(arg1, arg2);
                        debug log!("and ~x@~s, ~x\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    case 7: // cmp rm, imm
                        auto arg1 = loadRM!(T, A)(dataSeg, modrm);
                        auto arg2 = getImm!T;
                        cmp(arg1, arg2);
                        debug log!("cmp ~x@~s, ~x\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    default:
                        panic!("0x81/~n")(modrm.reg);
                }
            case 0x83:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 0: // add rm, imm8
                        auto addr = resolveRM!(T, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = getImm!ubyte;
                        *addr = add(arg1, arg2);
                        debug log!("add ~x@~s, ~x\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    case 1: // or rm, imm8
                        auto addr = resolveRM!(T, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = signExtend!T(getImm!ubyte);
                        *addr = or(arg1, arg2);
                        debug log!("or ~x@~s, ~x\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    case 4: // and rm, imm8
                        auto addr = resolveRM!(T, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = signExtend!T(getImm!ubyte);
                        *addr = and(arg1, arg2);
                        debug log!("and ~x@~s, ~x\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    case 5: // sub rm, imm8
                        auto addr = resolveRM!(T, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = getImm!ubyte;
                        *addr = sub(arg1, arg2);
                        debug log!("`sub` ~x@~s, ~x\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    case 7: // cmp rm, imm8
                        auto arg1 = loadRM!(T, A)(dataSeg, modrm);
                        auto arg2 = getImm!ubyte;
                        cmp(arg1, arg2);
                        debug log!("cmp ~x@~s, ~x\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    default:
                        panic!("0x83/~n")(modrm.reg);
                }
            case 0x84: // test rm8, reg
                auto modrm = getModRM();
                auto arg1 = loadRM!(ubyte, A)(dataSeg, modrm);
                auto arg2 = *regp!ubyte(modrm.reg);
                test(arg1, arg2);
                debug log!("test ~x@~s, ~x@~s\n")(arg1, mkShowRM!ubyte(modrm), arg2, regName!ubyte(modrm.reg));
                return true;
            case 0x85: // test rm, reg
                auto modrm = getModRM();
                auto arg1 = loadRM!(T, A)(dataSeg, modrm);
                auto arg2 = *regp!T(modrm.reg);
                test(arg1, arg2);
                debug log!("test ~x@~s, ~x@~s\n")(arg1, mkShowRM!T(modrm), arg2, regName!T(modrm.reg));
                return true;
            case 0x88: // mov rm8, reg
                auto modrm = getModRM();
                storeRM!(ubyte, A)(dataSeg, modrm, *regp!ubyte(modrm.reg));
                debug log!("`mov` ~s, ~x@~s\n")(mkShowRM!ubyte(modrm), storeValue, regName!ubyte(modrm.reg));
                return true;
            case 0x89: // mov rm, reg
                auto modrm = getModRM();
                auto value = *regp!T(modrm.reg);
                storeRM!(T, A)(dataSeg, modrm, value);
                debug log!("`mov` ~s, ~x@~s\n")(mkShowRM!T(modrm), value, regName!T(modrm.reg));
                return true;
            case 0x8A: // mov reg, rm8
                auto modrm = getModRM();
                *regp!ubyte(modrm.reg) = loadRM!(ubyte, A)(dataSeg, modrm);
                debug log!("`mov` ~s, ~x@~s\n")(regName!ubyte(modrm.reg), loadValue, mkShowRM!ubyte(modrm));
                return true;
            case 0x8B: // mov reg, rm
                auto modrm = getModRM();
                *regp!T(modrm.reg) = loadRM!(T, A)(dataSeg, modrm);
                debug log!("`mov` ~s, ~x@~s\n")(regName!T(modrm.reg), loadValue, mkShowRM!T(modrm));
                return true;
            case 0x8C: // mov rm, sreg
                auto modrm = getModRM();
                storeRM!(ushort, A)(dataSeg, modrm, seg[modrm.reg]);
                debug log!("`mov` ~s, ~x@~s\n")(mkShowRM!T(modrm), storeValue, segName(modrm.reg));
                return true;
            case 0x8D: // lea reg, m
                auto modrm = getModRM();
                *regp!T(modrm.reg) = effAddrRM!(T, A)(modrm);
                debug log!("lea ~s, ~s\n")(regName!T(modrm.reg), mkShowRM!T(modrm));
                return true;
            case 0x8E: // mov sreg, rm
                auto modrm = getModRM();
                seg[modrm.reg] = loadRM!(ushort, A)(dataSeg, modrm);
                debug log!("`mov` ~s, ~x@~s\n")(segName(modrm.reg), loadValue, mkShowRM!T(modrm));
                return true;
            case 0x8F:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 0: // pop rm
                        storeRM!(T, A)(dataSeg, modrm, pop!T);
                        debug log!("`pop` ~x!~s\n")(storeValue, mkShowRM!T(modrm));
                        return true;
                    default:
                        return false;
                }
            case 0x90: // nop
                return true;
            case 0x99: // cwd/cdq
                auto value = cast(asSigned!T) *regp!T(AX);
                *regp!T(DX) = cast(T) (value < 0 ? -1 : 0);
                debug log!("~s\n")(is(T == ushort) ? "cwd" : "cdq");
                return true;
            case 0x9C: // pushf
                static if (is(T == ushort))
                {
                    push!ushort(flags.reg);
                }
                else
                {
                    push!uint(flags.ereg);
                }
                debug log!("pushf\n");
                return true;
            case 0x9D: // popf
                static if (is(T == ushort))
                {
                    flags.reg = pop!ushort;
                }
                else
                {
                    flags.ereg = pop!uint;
                }
                debug log!("popf\n");
                return true;
            case 0xA0: // mov al, moffs
                auto offset = getImm!A;
                auto value = load(cast(ubyte*) (seg[dataSeg] * 0x10 + offset));
                gp[AX].low = value;
                debug log!("`mov` al, ~x@[~x]\n")(value, offset);
                return true;
            case 0xA1: // mov ax, moffs
                auto offset = getImm!A;
                auto value = load(cast(T*) (seg[dataSeg] * 0x10 + offset));
                *regp!T(AX) = value;
                debug log!("`mov` ~s, ~x@[~x]\n")(regName!T(AX), value, offset);
                return true;
            case 0xA3: // mov moffs, ax
                auto offset = getImm!A;
                auto value = *regp!T(AX);
                store(cast(T*) (seg[dataSeg] * 0x10 + offset), value);
                debug log!("`mov` [~x], ~x@~s\n")(offset, value, regName!T(AX));
                return true;
            case 0xA4: // movsb
                ushort count = 1;
                if (rep != Rep.None)
                {
                    count = gp[CX].reg;
                }
                auto si = *regp!A(SI);
                auto di = *regp!A(DI);
                auto src = cast(ubyte*) (seg[DS] * 0x10 + si);
                auto dst = cast(ubyte*) (seg[ES] * 0x10 + di);
                dst[0 .. count] = src[0 .. count];
                *regp!A(SI) += count;
                *regp!A(DI) += count;
                if (rep != Rep.None)
                {
                    gp[CX].reg = 0;
                    debug log!("movsb ~x:[~x .. ~x], ~x:[~x .. ~x]\n")(seg[ES], di, di + count, seg[DS], si, si + count);
                }
                else
                {
                    debug log!("movsb ~x:[~x], ~x:[~x]\n")(seg[DS], di, seg[ES], si);
                }
                return true;
            case 0xAA: // stosb
                ushort count = 1;
                if (rep != Rep.None)
                {
                    count = gp[CX].reg;
                }
                auto di = *regp!A(DI);
                auto value = gp[AX].low;
                auto ptr = cast(ubyte*) (seg[ES] * 0x10 + di);
                ptr[0 .. count] = value;
                *regp!A(DI) += count;
                if (rep != Rep.None)
                {
                    gp[CX].reg = 0;
                    debug log!("stosb ~x:[~x .. ~x], ~x\n")(seg[ES], di, di + count, value);
                }
                else
                {
                    debug log!("stosb ~x:[~x], ~x\n")(seg[ES], di, value);
                }
                return true;
            case 0xB0: .. case 0xB7: // mov reg, imm8
                int reg = op - 0xB0;
                auto imm = getImm!ubyte;
                *regp!ubyte(reg) = imm;
                debug log!("`mov` ~s, ~x\n")(regName!ubyte(reg), imm);
                return true;
            case 0xB8: .. case 0xBF: // mov reg, imm
                int reg = op - 0xB8;
                auto imm = getImm!T;
                *regp!T(reg) = imm;
                debug log!("`mov` ~s, ~x\n")(regName!T(reg), imm);
                return true;
            case 0xC1:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 4: // shl/sal rm, imm8
                        auto addr = resolveRM!(T, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = getImm!ubyte;
                        *addr = shl(arg1, arg2);
                        debug log!("shl ~x@~s, ~n\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    case 5: // shr rm, imm8
                        auto addr = resolveRM!(T, A)(dataSeg, modrm);
                        auto arg1 = *addr;
                        auto arg2 = getImm!ubyte;
                        *addr = shr(arg1, arg2);
                        debug log!("shr ~x@~s, ~n\n")(arg1, mkShowRM!T(modrm), arg2);
                        return true;
                    default:
                        panic!("0xC1/~x\n")(modrm.reg);
                }
            case 0xC2: // ret imm16
                auto imm = getImm!ushort;
                ip.reg = pop!ushort;
                gp[SP].reg += imm;
                debug log!("ret ~x -> ~x\n")(imm, ip.reg);
                return true;
            case 0xC3: // ret
                ip.reg = pop!ushort;
                debug log!("ret -> ~x\n")(ip.reg);
                return true;
            case 0xC6: // mov rm8, imm8
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 0:
                        auto imm = getImm!ubyte;
                        storeRM!(ubyte, A)(dataSeg, modrm, imm);
                        debug log!("`mov` ~s, ~x\n")(mkShowRM!T(modrm), imm);
                        return true;
                    default:
                        return false;
                }
            case 0xC7: // mov rm, imm
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 0:
                        auto imm = getImm!T;
                        storeRM!(T, A)(dataSeg, modrm, imm);
                        debug log!("`mov` ~s, ~x\n")(mkShowRM!T(modrm), imm);
                        return true;
                    default:
                        return false;
                }
            case 0xCD: // int
                ubyte index = getImm!ubyte;
                ushort hptr = load(cast(ushort*)(index * 4));
                ushort hseg = load(cast(ushort*)(index * 4 + 2));
                push!uint(flags.ereg);
                push!ushort(seg[CS]);
                push!ushort(ip.reg);
                seg[CS] = hseg;
                ip.reg = hptr;
                debug log!("`int` ~x\n")(index);
                return true;
            case 0xCF: // iret
                ip.reg = pop!ushort;
                seg[CS] = pop!ushort;
                flags.ereg = pop!uint;
                debug log!("iret -> ~x:~x\n")(seg[CS], ip.reg);
                return true;
            case 0xE8: // call rel
                auto disp = getImm!T;
                auto ret = ip.reg;
                push!ushort(ret);
                ip.reg += disp;
                debug log!("call ~x -> ~x {~x}\n")(disp, ip.reg, ret);
                return true;
            case 0xE9: // jmp rel
                auto disp = getImm!T;
                ip.reg += disp;
                debug log!("`jmp` ~x -> ~x\n")(disp, ip.reg);
                return true;
            case 0xEB: // jmp rel8
                auto disp = cast(byte) getImm!ubyte;
                ip.reg += disp;
                debug log!("`jmp` ~x -> ~x\n")(disp, ip.reg);
                return true;
            case 0xEC: // in al, dx
                auto port = gp[DX].reg;
                auto value = portInput(port);
                gp[AX].low = value;
                debug log!("in ~x@al, ~x@dx\n")(value, port);
                return true;
            case 0xEE: // out dx, al
                auto port = gp[DX].reg;
                auto value = gp[AX].low;
                portOutputByte(port, value);
                debug log!("out ~x@dx, ~x@al\n")(port, value);
                return true;
            case 0xEF: // out dx, ax
                auto port = gp[DX].reg;
                auto value = gp[AX].reg;
                portOutputWord(port, value);
                debug log!("out ~x@dx, ~x@ax\n")(port, value);
                return true;
            case 0xF2: // repnz
                debug log!("repnz ");
                return next!(T, A)(dataSeg, Rep.NZ);
            case 0xF3: // repz
                debug log!("repz ");
                return next!(T, A)(dataSeg, Rep.Z);
            case 0xF6:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 0: // test rm8, imm8
                        ubyte arg1 = loadRM!(ubyte, A)(dataSeg, modrm);
                        ubyte arg2 = getOp();
                        test(arg1, arg2);
                        debug log!("test ~x@[~p], byte ~x\n")(loadValue, loadAddr, arg2);
                        return true;
                    default:
                        return false;
                }
            case 0xF7:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 6: // div rm
                        auto arg = loadRM!(T, A)(dataSeg, modrm);
                        auto low = *regp!T(AX);
                        auto high = *regp!T(DX);
                        auto values = div(low, high, arg);
                        *regp!T(AX) = values[0];
                        *regp!T(DX) = values[1];
                        debug log!("div ~x@~s {~x:~x -> ~x:~x}\n")(loadValue, mkShowRM!T(modrm), high, low, values[1], values[0]);
                        return true;
                    case 7: // idiv rm
                        auto arg = loadRM!(T, A)(dataSeg, modrm);
                        auto low = *regp!T(AX);
                        auto high = *regp!T(DX);
                        auto values = idiv(low, high, arg);
                        *regp!T(AX) = values[0];
                        *regp!T(DX) = values[1];
                        debug log!("idiv ~x@~s {~x:~x -> ~x:~x}\n")(loadValue, mkShowRM!T(modrm), high, low, values[1], values[0]);
                        return true;
                    default:
                        panic!("0xF7/~n")(modrm.reg);
                }
            case 0xFA: // cli
                debug log!("cli\n");
                return true;
            case 0xFB: // sti
                debug log!("sti\n");
                return true;
            case 0xFC: // cld
                debug log!("cld\n");
                return true;
            case 0xFE:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 1: // dec rm8
                        auto addr = resolveRM!(ubyte, A)(dataSeg, modrm);
                        auto arg = *addr;
                        *addr = dec(arg);
                        debug log!("dec ~x@~s\n")(arg, mkShowRM!ubyte(modrm));
                        return true;
                    default:
                        panic!("0xFE/~n")(modrm.reg);
                }
            case 0xFF:
                auto modrm = getModRM();
                switch (modrm.reg)
                {
                    case 2: // call rm
                        auto target = loadRM!(T, A)(dataSeg, modrm);
                        auto ret = ip.reg;
                        push!ushort(ret);
                        ip.ereg = 0;
                        ip.reg = cast(ushort) target;
                        assert(ip.ereg == target);
                        debug log!("call ~x@~s {~x}\n")(ip.reg, mkShowRM!T(modrm), ret);
                        return true;
                    case 6: // push rm
                        push!T(loadRM!(T, A)(dataSeg, modrm));
                        debug log!("`push` ~x@~s\n")(loadValue, mkShowRM!T(modrm));
                        return true;
                    case 7:
                        return false;
                    default:
                        panic!("0xFF/~n")(modrm.reg);
                }
            default:
                return false;
        }
    }

    int run(int maxCount = int.max)
    {
        int count = 0;
        uint ipLast = ip.ereg;
        while (count < maxCount && next!(ushort, ushort)(DS, Rep.None))
        {
            ipLast = ip.ereg;
            count += 1;
        }
        ip.ereg = ipLast;
        return count;
    }
}
