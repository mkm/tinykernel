module keyboard;

import prim;
import traits;
import terminal;

__gshared Keyboard kbd;

enum Key
{
    A = 0x1E,
    B = 0x30,
    C = 0x2E,
    D = 0x20,
    E = 0x12,
    F = 0x21,
    G = 0x22,
    H = 0x23,
    I = 0x17,
    J = 0x24,
    K = 0x25,
    L = 0x26,
    M = 0x32,
    N = 0x31,
    O = 0x18,
    P = 0x19,
    Q = 0x10,
    R = 0x13,
    S = 0x1F,
    T = 0x14,
    U = 0x16,
    V = 0x2F,
    W = 0x11,
    X = 0x2D,
    Y = 0x15,
    Z = 0x2C,
    N0 = 0x0B,
    N1 = 0x02,
    N2 = 0x03,
    N3 = 0x04,
    N4 = 0x05,
    N5 = 0x06,
    N6 = 0x07,
    N7 = 0x08,
    N8 = 0x09,
    N9 = 0x0A,
    Space = 0x39,
    Enter = 0x1C,
    Back = 0x0E,
    Delete = 0x153,
    PageUp = 0x149,
    PageDown = 0x151,
    Escape = 0x01,
    Tab = 0x0F,
    LCtrl = 0x1D,
    RCtrl = 0x11D,
    LShift = 0x2A,
    RShift = 0x36
}

void showKey(Terminal* term, Key key)
{
    switch (key)
    {
        static foreach (k; allMembers!Key)
        {
            case getMember!(Key, k):
                term.write(k);
                return;
        }
        default:
            format!("[~x]")(term, cast(uint) key);
    }
}

struct KeyEvent
{
    enum Type
    {
        Press,
        Release
    }

    Type type;
    ubyte scanCode;
    Key key;

    this(bool ext, ubyte scanCode)
    {
        type = scanCode & 0x80 ? Type.Release : Type.Press;
        this.scanCode = scanCode;
        key = cast(Key) (ext * 0x100 + scanCode & ~0x80);
    }

    void show(Terminal* term)
    {
        format!("~s/~x/")(term, type == Type.Press ? "p" : "r", scanCode);
        showKey(term, key);
    }
}

struct Keyboard
{
    KeyEvent event;
    bool hasEvent;
    bool extendedKey;

    private bool hasResponse()
    {
        auto status = portInput(0x64);
        return status & 0x01;
    }

    private void waitForResponse()
    {
        while (!hasResponse()) {}
    }

    private void fetchResponse()
    {
        waitForResponse();
        ubyte response = portInput(0x60);
        switch (response)
        {
            case 0xE0:
                extendedKey = true;
                break;
            default:
                event = KeyEvent(extendedKey, response);
                hasEvent = true;
                extendedKey = false;
        }
    }

    void reset()
    {
        while (hasResponse())
        {
            fetchResponse();
        }
        hasEvent = false;
        extendedKey = false;
    }

    KeyEvent getEvent()
    {
        while (!hasEvent)
        {
            fetchResponse();
        }
        hasEvent = false;
        return event;
    }
}
