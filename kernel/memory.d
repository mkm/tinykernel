module memory;

import util;
import virtmem;
import terminal;

void* alloc(size_t size)
{
    auto pages = aligned(0x1000, size) / 0x1000;
    return vmm.alloc(pages);
}

void free(void* ptr)
{}

T* make(T, Args...)(Args args)
{
    auto ptr = cast(T*) alloc(T.sizeof);
    (*ptr).emplace(args);
    return ptr;
}

struct Unique(T)
{
    T* ptr;

    this(T* ptr)
    {
        this.ptr = ptr;
    }

    @disable this(ref Unique);

    ~this()
    {
        if (ptr)
        {
            free(ptr);
        }
    }

    T* release()
    {
        T* result = ptr;
        ptr = null;
        return result;
    }

    Unique dup()
    {
        return makeUnique!T(*this);
    }

    alias ptr this;
}

Unique!T makeUnique(T, Args...)(Args args)
{
    return Unique!T(make!T(args));
}

struct RC(T)
{
    struct Cell
    {
        size_t count;
        T value;

        this(Args...)(Args args)
        {
            this.count = 1;
            this.value = T(args);
        }
    }

    Cell* cell;

    static void inc(Cell* cell)
    {
        cell.count += 1;
    }

    static void dec(ref Cell* cell)
    {
        cell.count -= 1;
        if (!cell.count)
        {
            destroy(cell);
            free(cell);
            cell = null;
        }
    }

    this(Cell* cell)
    {
        this.cell = cell;
    }

    this(ref RC other)
    {
        this.cell = other.cell;
        inc(cell);
    }

    ~this()
    {
        if (cell)
        {
            dec(cell);
        }
    }

    void opAssign(ref RC other)
    {
        inc(other.cell);
        dec(this.cell);
        this.cell = other.cell;
    }

    @property inout(T)* ptr() inout
    {
        return &cell.value;
    }

    @property size_t count() const
    {
        return cell.count;
    }

    void show(char mod)(Terminal* term) const
    {
        if (cell)
        {
            terminal.show!mod(term, cell);
            term.write('/');
            terminal.show!'n'(term, count);
        }
        else
        {
            term.write("null");
        }
    }

    alias ptr this;
}

RC!T makeRC(T, Args...)(Args args)
{
    return RC!T(make!(RC!T.Cell)(args));
}
