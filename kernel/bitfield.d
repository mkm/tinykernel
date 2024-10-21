module bitfield;

import util;
import terminal;

struct BitField(size_t N) if (N <= 64)
{
    static if (N <= 8)
    {
        alias Bits = ubyte;
    }
    else static if (N <= 16)
    {
        alias Bits = ushort;
    }
    else static if (N <= 32)
    {
        alias Bits = uint;
    }
    else
    {
        alias Bits = ulong;
    }

    Bits bits;

    bool opIndex(size_t index)
    in(index < N)
    {
        return (bits >> index) & 1;
    }

    ulong opSlice(size_t a, size_t b)
    in(a <= b)
    {
        return (bits >> a) & ~(cast(Bits) -1 << (b - a));
    }

    void opIndexAssign(bool value, size_t index)
    {
        bits &= ~(1 << index);
        bits |= value << index;
    }

    void opSliceAssign(Bits value, size_t a, size_t b)
    in(a <= b)
    in(value >> b - a == 0)
    {
        bits &= ~(~(cast(Bits) -1 << (b - a)) << a);
        bits |= value << a;
    }

    void show(Terminal* term)
    {
        for (size_t i = N; i > 0; --i)
        {
            term.write(cast(char) (cast(ubyte) '0' + this[i - 1]));
        }
    }
}

struct BitField(size_t N) if (N > 64)
{
    BitField!64[aligned(64, N) / 64] words;

    bool opIndex(size_t index)
    in(index < N)
    {
        return words[index / 64][index % 64];
    }

    void opIndexAssign(bool value, size_t index)
    {
        words[index / 64][index % 64] = value;
    }

    void show(Terminal* term)
    {
        for (size_t i = N; i > 0; --i)
        {
            term.write(cast(char) (cast(ubyte) '0' + this[i - 1]));
        }
    }
}
