module panic;

import prim;
import textmode;
import shell;
import format : format;

noreturn panic(string fmt, T...)(T args)
{
    if (kshell.workspaces.length)
    {
        auto buffer = kshell.buffer(0);
        buffer.currentAttr = Attr(Colour.Red, Colour.Blue);
        format!(fmt)(*buffer, args);
        kshell.interact();
    }
    else
    {
        writeText(Pos(0, 0), Attr(Colour.Red, Colour.Blue), fmt);
    }

    while (true)
    {
        halt();
    }
}
