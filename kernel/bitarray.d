module bitarray;

import bitfield;

bool getBit(ubyte value, size_t bit)
in(bit < 8)
{
    return (value >> bit) & 1;
}

void putBit(ref ubyte bits, size_t bit, bool value)
{
    if (value)
    {
        bits |= 1 << bit;
    }
    else
    {
        bits &= ~(1 << bit);
    }
}

struct BitArray
{
    size_t length;
    BitField!8* ptr;

    struct Slice
    {
        size_t from;
        size_t to;
    }

    size_t[2] opSlice(int _)(size_t a, size_t b)
    {
        return [a, b];
    }

    bool opIndex(size_t index)
    {
        return ptr[index >> 3][index & 0b111];
    }

    void opIndexAssign(bool value, size_t index)
    {
        ptr[index >> 3][index & 0b111] = value;
    }

    void opIndexAssign(bool value, size_t[2] range)
    {
        foreach (index; range[0] .. range[1])
        {
            this[index] = value;
        }
    }
}
