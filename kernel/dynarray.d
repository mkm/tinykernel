module dynarray;

import memory;
import terminal;

struct DynArray(T)
{
    private enum initialSize = 16;

    private T[] _storage;
    private size_t _length;

    @disable this(this);
    @disable this(ref DynArray);

    ~this()
    {
        free(_storage.ptr);
        _storage = null;
        _length = 0;
    }

    private void grow()
    {
        if (!_storage.length)
        {
            T* ptr = cast(T*) alloc(initialSize * T.sizeof);
            _storage = ptr[0 .. initialSize];
        }
        else
        {
            size_t newSize = _storage.length * 2;
            T* ptr = cast(T*) alloc(newSize * T.sizeof);
            foreach (i; 0 .. _length)
            {
                ptr[i] = _storage[i];
            }
            // ptr[0 .. _length] = _storage[0 .. _length];
            free(_storage.ptr);
            _storage = ptr[0 .. newSize];
        }
    }

    @property inout(T)[] data() inout
    {
        return _storage[0 .. _length];
    }

    @property T* ptr()
    {
        return data.ptr;
    }

    @property size_t length() const
    {
        return data.length;
    }

    ref inout(T) opIndex(size_t index) inout
    {
        return data[index];
    }

    inout(T)[] opSlice(size_t a, size_t b) inout
    {
        return data[a .. b];
    }

    @property size_t capacity()
    {
        return _storage.length;
    }

    void push(T value)
    {
        if (_length == _storage.length)
        {
            grow();
        }

        _storage[_length] = value;
        _length += 1;
    }

    void show(char mod)(Terminal* term) const
    {
        terminal.show!mod(term, _storage[0 .. _length]);
    }
}
