module traits;

bool isIntegral(T)()
{
    return __traits(isIntegral, T);
}

bool isUnsigned(T)()
{
    return __traits(isUnsigned, T);
}

template asSigned(T)
{
    static assert(false, "not an arithmetic type");
}

alias asSigned(T : ubyte) = byte;
alias asSigned(T : ushort) = short;
alias asSigned(T : uint) = int;
alias asSigned(T : ulong) = long;

alias stripConst(T) = T;
alias stripConst(T : const(U), U) = U;
alias stripConst(T : immutable(U), U) = U;

string identifier(alias x)()
{
    return __traits(identifier, x);
}

bool hasMember(alias x, string name)()
{
    return __traits(hasMember, x, name);
}

template getMember(alias x, string name)
{
    alias getMember = __traits(getMember, x, name);
}

template allMembers(T)
{
    alias allMembers = __traits(allMembers, T);
}

private struct NoAttr;

template getAttributes(alias x)
{
    static if (__traits(compiles, __traits(getAttributes, x)))
    {
        alias getAttributes = __traits(getAttributes, x);
    }
    else
    {
        alias getAttributes = __traits(getAttributes, NoAttr);
    }
}

bool hasAttribute(alias x, alias attr)()
{
    bool result = false;
    static foreach (a; getAttributes!x)
    {
        static if (a == attr)
        {
            result = true;
        }
    }
    return result;
}

struct Derive
{
    string behaviour;
}
