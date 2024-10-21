module bios;

import util;
import lowmem;
import terminal;
import vm86;

struct BiosCall
{
    ubyte interrupt;
    ubyte func;
    ubyte subfunc;
    ushort cx;
    union
    {
        struct
        {
            ubyte dl;
            ubyte dh;
        }
        uint edx;
    }
    uint ebx;
    ushort es;
    ushort di;
    bool carry;

    void opCall()
    {
        auto bios = lowMem.alloc!ubyte(3);
        bios[0 .. 3] = array!ubyte(0xCD, interrupt, 0xCC);
        auto stack = lowMem.alloc!ubyte(0x20);
        VM vm;
        vm.seg[CS] = bios.seg;
        vm.ip.reg = bios.off;
        vm.gp[SP].reg = cast(ushort) (stack.off + 0x20);
        vm.seg[SS] = stack.seg;
        vm.gp[AX].high = func;
        vm.gp[AX].low = subfunc;
        vm.gp[CX].reg = cx;
        vm.gp[DX].ereg = edx;
        vm.gp[BX].ereg = ebx;
        vm.seg[ES] = es;
        vm.gp[DI].reg = di;
        vm.run();
        ubyte* ip = cast(ubyte*)(vm.seg[CS] * 0x10 + vm.ip.ereg);
        assert(ip[0] == 0xCC);
        carry = vm.flags.c;
        ebx = vm.gp[BX].ereg;
        cx = vm.gp[CX].reg;
    }
}
