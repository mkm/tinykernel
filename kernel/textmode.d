module textmode;

import bitfield;
import vga;

enum TextModeWidth = 80;
enum TextModeHeight = 25;

struct Pos
{
    int x;
    int y;
}

enum Colour : ubyte
{
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    Grey,
    DarkGrey,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    Yellow,
    White
}

Colour toggleBrightness(Colour colour)
{
    return cast(Colour) (cast(ubyte) colour ^ 0x8);
}

struct Attr
{
    BitField!8 data;

    @property Colour foreground()
    {
        return cast(Colour) data[0 .. 4];
    }

    @property void foreground(Colour colour)
    {
        data[0 .. 4] = colour;
    }

    @property Colour background()
    {
        return cast(Colour) data[4 .. 8];
    }

    @property void background(Colour colour)
    {
        data[4 .. 8] = colour;
    }

    this(Colour fg, Colour bg)
    {
        this.foreground = fg;
        this.background = bg;
    }
}

struct Texel
{
    char sym;
    Attr attr;
}

@property Texel* textModeBase()
{
    return cast(Texel*) 0xB8000;
}

void setTextCursorPos(Pos pos)
{
    setCursorPos(pos.x + pos.y * TextModeWidth);
}

void clearText(Attr attr, char sym = ' ')
{
    auto texel = Texel(sym, attr);
    textModeBase[0 .. TextModeWidth * TextModeHeight] = texel;
}

void writeText(Pos pos, Attr attr, const char[] text)
in(pos.x + text.length <= TextModeWidth)
{
    Texel* tex = textModeBase + pos.y * TextModeWidth + pos.x;
    foreach (i, c; text)
    {
        tex[i].sym = c;
        tex[i].attr = attr;
    }
}

void writeText(Pos pos, const Texel[] text)
in(pos.x + text.length <= TextModeWidth)
{
    Texel* tex = textModeBase + pos.y * TextModeWidth + pos.x;
    tex[0 .. text.length] = text;
}
