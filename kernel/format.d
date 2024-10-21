module format;

import traits;

void show(char mod, T, Stream)(ref Stream stream, const T[] array)
{
    static if (is(T == void))
    {
        stream.write('[');
        show!mod(stream, array.ptr);
        stream.write(" .. ");
        show!mod(stream, array.ptr + array.length);
        stream.write(']');
    }
    else static if (is(T == char))
    {
        static if (mod == 'q')
        {
            stream.write('"');
        }
        stream.write(array);
        static if (mod == 'q')
        {
            stream.write('"');
        }
    }
    else
    {
        stream.write('[');
        bool comma = false;
        foreach (x; array)
        {
            if (comma)
            {
                stream.write(", ");
            }
            comma = true;
            show!mod(stream, x);
        }
        stream.write(']');
    }
}

void show(char mod, T, Stream)(ref Stream stream, T num) if (isIntegral!T)
{
    int base = 10;

    static if (mod == 'x')
    {
        base = 16;
        stream.write("0x");
    }

    stripConst!T n = num;

    static if (!isUnsigned!T)
    {
        if (n < 0)
        {
            stream.write('-');
            n = cast(T) -n;
        }
    }

    if (num == 0)
    {
        stream.write('0');
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

    stream.write(digits[start .. $]);
}

void show(char mod, T, Stream)(ref Stream stream, T* ptr)
{
    show!('x')(stream, cast(size_t) ptr);
}

void show(char mod, T, Stream)(ref Stream stream, in T obj) if (hasMember!(T, "show"))
{
    obj.show!mod(stream);
}

void show(char mod, T, Stream)(ref Stream stream, in T obj) if (hasAttribute!(T, Derive("show")))
{
    stream.write(identifier!T);
    stream.write('(');
    alias members = allMembers!T;
    static foreach (i; 0 .. obj.tupleof.length)
    {
        static if (i > 0)
        {
            stream.write(", ");
        }
        show!mod(stream, obj.tupleof[i]);
    }
    stream.write(')');
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

void format(string fmt, Stream, T...)(ref Stream stream, in T args)
{
    immutable int tildePos = nextTilde(fmt);
    static if (tildePos == -1)
    {
        stream.write(fmt);
    }
    else
    {
        stream.write(fmt[0 .. tildePos]);
        enum char mod = fmt[tildePos + 1];
        show!(mod)(stream, args[0]);
        format!(fmt[tildePos + 2 .. $])(stream, args[1 .. $]);
    }
}

