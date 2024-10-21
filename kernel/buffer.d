module buffer;

import util;
import dynarray;
import textmode;

struct Buffer
{
    DynArray!Texel text;
    DynArray!size_t lines;
    Attr currentAttr;

    @disable this();
    @disable this(this);
    @disable this(ref Buffer);
    @disable void opAssign(ref Buffer);

    this(Construct)
    {
        lines.push(0);
        this.currentAttr = Attr(Colour.Grey, Colour.Black);
    }

    void write(char c)
    {
        if (c == '\n')
        {
            lines.push(text.length);
        }
        else if (c == '`')
        {
            currentAttr.foreground = toggleBrightness(currentAttr.foreground);
        }
        else
        {
            text.push(Texel(c, currentAttr));
        }
    }

    void write(const char[] s)
    {
        foreach (c; s)
        {
            write(c);
        }
    }

    @property size_t lineCount() const
    {
        return lines.length;
    }

    size_t lineOffset(size_t i) const
    {
        return i == lines.length ? text.length : lines[i];
    }

    const(Texel)[] line(size_t i) const
    {
        return text[lineOffset(i) .. lineOffset(i + 1)];
    }
}
