module global;

template zeroes(size_t n)
{
    static if (n == 0)
    {
        enum string zeroes = "";
    }
    else static if (n == 1)
    {
        enum string zeroes = "\0";
    }
    else
    {
        enum string zeroes = zeroes!(n / 2) ~ zeroes!(n - n / 2);
    }
}

extern (C) T* gptr(T, string name)()
{
    enum int alignment = T.alignof;
    enum string data = zeroes!(T.sizeof);
    asm
    {
        naked;
        lea RAX, [object];
        ret;
        align alignment;
    object:
        db data;
    }
}

mixin template declareGlobal(T, string name)
{
    mixin("@property ref T ", name, "() { return *gptr!(T, name); }");
}
