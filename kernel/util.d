module util;

struct Construct {}

struct FarPtr(T)
{
    ushort off;
    ushort seg;

    this(T* ptr)
    in(cast(ulong) ptr < 0x10000)
    {
        auto addr = cast(uint) ptr;
        this.seg = cast(ushort) (addr >> 4);
        this.off = cast(ushort) (addr & 0xF);
    }

    this(ushort off, ushort seg)
    {
        this.seg = seg;
        this.off = off;
    }

    @property T* ptr()
    {
        return cast(T*) (seg * 0x10 + off);
    }

    T opUnary(string op)() if (op == "*")
    {
        return *ptr;
    }

    alias ptr this;
}

void blit(T)(ref T dst, in T src)
{
    (cast(ubyte*) &dst)[0 .. T.sizeof] = (cast(ubyte*) &src)[0 .. T.sizeof];
}

void emplace(T, Args...)(ref T obj, Args args)
{
    blit(obj, T.init);
    static if (args.length)
    {
        obj.__ctor(args);
    }
}

T aligned(T)(T a, T val)
{
    return (val + a - 1) & ~(a - 1);
}

T KiB(T)(T n)
{
    return n << 10;
}

T MiB(T)(T n)
{
    return n << 20;
}

T GiB(T)(T n)
{
    return n << 30;
}

inout(T)[] fromCString(T)(inout(T)* ptr)
{
    size_t length = 0;
    while (ptr[length])
    {
        length += 1;
    }
    return ptr[0 .. length];
}

auto array(T, Ts...)(T arg, Ts args)
{
    T[1 + args.length] value = [cast(T) arg, cast(T) args[]];
    return value;
}

auto min(T)(T a, T b)
{
    return a < b ? a : b;
}

size_t find(T)(T needle, T[] haystack)
{
    size_t index = 0;
    while (index < haystack.length && haystack[index] != needle)
    {
        index += 1;
    }
    return index;
}
