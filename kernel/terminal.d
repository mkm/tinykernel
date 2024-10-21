module terminal;

import prim;
import traits;
import util;
import vga;

__gshared Terminal stdout;

struct Terminal
{
    struct Texel
    {
        char sym;
        ubyte colour;
    }

    Texel* base;
    int width;
    int height;
    int col;
    int row;
    ubyte colour;

    this(void* base, int width, int height)
    {
        this.base = cast(Texel*) base;
        this.width = width;
        this.height = height;
        this.colour = 0x07;
    }

    void clear()
    {
        foreach (i; 0 .. width * height)
        {
            base[i].sym = ' ';
            base[i].colour = 0x07;
        }
    }

    void writeRaw(char c)
    {
        base[row * width + col].sym = c;
        base[row * width + col].colour = colour;
        col += 1;
        if (col >= width)
        {
            newline();
        }
    }

    void newline()
    {
        col = 0;
        row += 1;

        if (row >= height)
        {
            scroll();
        }
    }

    void scroll()
    {
        row -= 1;

        foreach (r; 0 .. height - 1)
        {
            foreach (c; 0 .. width)
            {
                base[r * width + c] = base[(r + 1) * width + c];
            }
        }

        foreach (c; 0 .. width)
        {
            base[(height - 1) * width + c].sym = ' ';
        }
    }

    void write(char c)
    {
        switch (c)
        {
            case '\n':
                newline();
                break;
            default:
                writeRaw(c);
        }
    }

    void write(const char[] s)
    {
        foreach (char c; s)
        {
            write(c);
        }
    }

    void syncCursor()
    {
        setCursorPos(row * width + col);
    }
}

void show(char mod)(Terminal* term, const char[] s)
{
    static if (mod == 'q')
    {
        term.write('"');
    }
    term.write(s);
    static if (mod == 'q')
    {
        term.write('"');
    }
}

void show(char mod, T)(Terminal* term, T[] array)
{
    static if (is(T == void))
    {
        term.write('[');
        show!mod(term, array.ptr);
        term.write(" .. ");
        show!mod(term, array.ptr + array.length);
        term.write(']');
    }
    else
    {
        term.write('[');
        bool comma = false;
        foreach (x; array)
        {
            if (comma)
            {
                term.write(", ");
            }
            comma = true;
            show!mod(term, x);
        }
        term.write(']');
    }
}

void show(char mod, T)(Terminal* term, T num) if (isIntegral!T)
{
    int base = 10;

    static if (mod == 'x')
    {
        base = 16;
        term.write("0x");
    }

    stripConst!T n = num;

    static if (!isUnsigned!T)
    {
        if (n < 0)
        {
            term.write('-');
            n = cast(T) -n;
        }
    }

    if (num == 0)
    {
        term.write('0');
        return;
    }

    char[32] digits;
    int start = digits.length;
    while (n > 0)
    {
        auto digit = cast(stripConst!T) (n % base);
        n = cast(stripConst!T) (n / base);
        start -= 1;
        digits[start] = "0123456789ABCDEF"[digit];
    }

    term.write(digits[start .. $]);
}

void show(char mod, T)(Terminal* term, T* ptr)
{
    show!('x')(term, cast(size_t) ptr);
}

void show(char mod, T)(Terminal* term, in T obj) if (hasMember!(T, "show"))
{
    obj.show!mod(term);
}

void show(char mod, T)(Terminal* term, in T obj) if (hasAttribute!(T, Derive("show")))
{
    term.write(identifier!T);
    term.write('(');
    alias members = allMembers!T;
    static foreach (i; 0 .. obj.tupleof.length)
    {
        static if (i > 0)
        {
            term.write(", ");
        }
        show!mod(term, obj.tupleof[i]);
    }
    term.write(')');
}

int nextTilde(string fmt)
{
    foreach (i; 0 .. fmt.length)
    {
        if (fmt[i] == '~')
        {
            return cast(int) i;
        }
    }

    return -1;
}

void format(string fmt, T...)(Terminal* term, in T args)
{
    immutable int tildePos = nextTilde(fmt);
    static if (tildePos == -1)
    {
        term.write(fmt);
    }
    else
    {
        term.write(fmt[0 .. tildePos]);
        immutable char mod = fmt[tildePos + 1];
        show!(mod)(term, args[0]);
        format!(fmt[tildePos + 2 .. $])(term, args[1 .. $]);
    }
}

void print(string fmt, T...)(in T args)
{
    format!(fmt)(&stdout, args);
}

noreturn panic(string fmt, T...)(T args)
{
    auto console = Terminal(cast(void*) 0xB8000, 80, 25);
    stdout.colour = 0x74;
    stdout.write("\nPANIC\n");
    print!(fmt)(args);

    while (true)
    {
        halt();
    }
}
