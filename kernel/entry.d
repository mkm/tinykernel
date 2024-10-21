module entry;

import core.lifetime;

import prim;
import util;
import bitfield;
import bitarray;
import interrupt;
import textmode;
import format : format;
import terminal;
import keyboard;
import lowmem;
import physmem;
import virtmem;
import memory;
import dynarray;
import buffer;
import shell;
import vm86;
import bios;
import vga;
import panic : panic;

extern (C) noreturn _start(size_t kernelSize)
{
    kmain(kernelSize);
    while (true)
    {
        halt();
    }
}

void kmain(size_t kernelSize)
{
    setupIDT();

    stdout.emplace(cast(void*) 0xB8000, 40, 50);
    stdout.clear();
    print!("Kernel size: ~x\n")(kernelSize);

    lowMem.emplace(0x68000);

    pmm.emplace(kernelSize);
    vmm.emplace(Construct());
    kbd.emplace();
    kbd.reset();

    kshell.emplace();
    auto mainWorkspace = kshell.createWorkspace();
    auto buf = kshell.buffer(mainWorkspace);
    buf.write("Lorem ipsum\n");
    buf.write("Dolor sit amet\n");
    int pos = cast(short) getCursorPosBios();
    buf.format!("Cursor: ~n (~n, ~n)\n")(pos, pos % TextModeWidth, pos / TextModeWidth);
    auto otherWorkspace = kshell.createWorkspace();
    buf = kshell.buffer(otherWorkspace);
    buf.write("Telephone\n");
    buf.write("Saxophone\n");
    format!("Megaphone ~n\n")(buf, 8000);
    auto vmBuf = kshell.buffer(kshell.createWorkspace());

    auto bios = lowMem.alloc!ubyte(3);
    bios[0 .. 3] = array!ubyte(0xCD, 0x15, 0xCC);
    size_t stackSpace = 0x100;
    auto stack = lowMem.alloc!ubyte(stackSpace);
    auto info = lowMem.alloc!VGAInfo;
    info.ptr.signature[0 .. 4] = "VBE2";
    getVGAInfo(info);
    size_t modeCount = find(0xFFFF, info.modes[0 .. size_t.max]);
    ushort[] modes = info.modes[0 .. modeCount];
    auto modeInfo = lowMem.alloc!VGAModeInfo;
    print!("mode at ~p ~p\n")(info.ptr, modeInfo.ptr);
    auto memInfo = lowMem.alloc!ubyte(20);

    VM vm;
    // debug vm.console = &stdout;
    debug vm.console = vmBuf;
    vm.ip.reg = bios.off;
    vm.seg[CS] = bios.seg;
    vm.gp[SP].reg = cast(ushort) (stack.off + stackSpace);
    vm.seg[SS] = stack.seg;
    vm.gp[AX].reg = 0xE820;
    vm.gp[CX].reg = 20;
    vm.gp[DX].ereg = 0x534D4150;
    // vm.gp[BX].reg = 0x144 | 0x4000;
    // vm.gp[CX].reg = 0;
    vm.gp[DI].reg = memInfo.off;
    vm.seg[ES] = memInfo.seg;
    int count = vm.run(5);
    ubyte* ip = cast(ubyte*)(vm.seg[CS] * 0x10 + vm.ip.ereg);
    /*
    print!("Execution stopped after ~n steps\n")(count);
    print!("ip: [~x ~x ~x ~x ~x ~x]\n")(ip[0], ip[1], ip[2], ip[3], ip[4], ip[5]);
    print!("eip = ~x\n")(vm.ip.ereg);
    print!("eax = ~x, ecx = ~x, edx = ~x, ebx = ~x\n")(vm.gp[AX].ereg, vm.gp[CX].ereg, vm.gp[DX].ereg, vm.gp[BX].ereg);
    print!("esp = ~x, ebp = ~x, esi = ~x, edi = ~x\n")(vm.gp[SP].ereg, vm.gp[BP].ereg, vm.gp[SI].ereg, vm.gp[DI].ereg);
    print!("cs = ~x, ds = ~x, es = ~x, fs = ~x, gs = ~x, ss = ~x\n")(vm.seg[CS], vm.seg[DS], vm.seg[ES], vm.seg[FS], vm.seg[GS], vm.seg[SS]);
    print!("flags = ~x\n")(vm.flags);
    */

    print!("# ~s ~n.~n ~s\n")(info.ptr.signature, info.ptr.vers[1], info.ptr.vers[0], fromCString(info.ptr.oemName.ptr));

    auto vgaBuf = kshell.buffer(kshell.createWorkspace());
    foreach (mode; modes)
    {
        vgaBuf.format!("~x ")(mode);
        getVGAModeInfo(mode, modeInfo);
        vgaBuf.format!("~s ~nx~nx~n addr=~x\n")(modeInfo.attr[3] ? "G" : "T", modeInfo.width, modeInfo.height, modeInfo.bitsPerPixel, modeInfo.videoAddr);
    }

    auto foo = makeRC!uint(0xDEADBEEF);
    auto bar = foo;
    foo = bar;
    print!("~x ~n\n")(*foo, foo.count);
    // auto buf = cast(RC!Buffer.Cell*) alloc((RC!Buffer.Cell).sizeof);
    // emplace!(RC!Buffer.Cell)(buf, Construct());
    // *buf = RC!Buffer.Cell.init;
    // *buf = RC!Buffer.Cell(Construct());
    // auto buf = make!(RC!Buffer.Cell)(Construct());
    // auto buf = makeRC!Buffer(Construct());
    // print!("~p\n")(meh);
    // stdout.syncCursor();

    // Output to multiple logs. Console with tabs.
    while (!truth())
    {
        auto event = kbd.getEvent();
        if (event.type == KeyEvent.Type.Press)
        {
            showKey(&stdout, event.key);
            stdout.syncCursor();
        }
    }

    kshell.interact();
    print!("Bye...\n");
}
