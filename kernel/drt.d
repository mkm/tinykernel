module drt;

import util;
// import terminal;
import panic : panic;

extern (C) void __assert(const char* expr, const char* file, int line)
{
    panic!("~s:~n `~s`")(fromCString(file), line, fromCString(expr));
}

extern (C) ubyte* memset(ubyte* ptr, ubyte value, size_t count)
{
    foreach (i; 0 .. count)
    {
        ptr[i] = value;
    }
    return ptr;
}

extern (C) void _memset16(short* ptr, short value, size_t count)
{
    foreach (i; 0 .. count)
    {
        ptr[i] = value;
    }
}

extern (C) void _memset32(int* ptr, int value, size_t count)
{
    foreach (i; 0 .. count)
    {
        ptr[i] = value;
    }
}

extern (C) void _memset64(long* ptr, long value, size_t count)
{
    foreach (i; 0 .. count)
    {
        ptr[i] = value;
    }
}

extern (C) void _memset128ii(long* ptr, long value1, long value2, size_t count)
{
    foreach (i; 0 .. count)
    {
        ptr[i * 2] = value1;
        ptr[i * 2 + 1] = value2;
    }
}

extern (C) int memcmp(const ubyte* p, const ubyte* q, size_t count)
{
    foreach (i; 0 .. count)
    {
        if (p[i] < q[i])
        {
            return -1;
        }
        else if (p[i] > q[i])
        {
            return 1;
        }
    }
    return 0;
}
