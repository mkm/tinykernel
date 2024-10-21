module shell;

import prim;
import util;
import memory;
import buffer;
import dynarray;
import textmode;
import keyboard;

__gshared Shell kshell;

struct Shell
{
    struct Workspace
    {
        RC!Buffer buffer;

        void opAssign(ref Workspace other)
        {
            foreach (i, ref field; other.tupleof)
            {
                this.tupleof[i] = field;
            }
        }
    }

    alias WorkspaceId = size_t;

    DynArray!Workspace workspaces;
    WorkspaceId activeWorkspace;

    WorkspaceId createWorkspace()
    {
        auto id = workspaces.length;
        auto buf = makeRC!Buffer(Construct());
        workspaces.push(Workspace(buf));
        return id;
    }

    inout(Buffer)* buffer(WorkspaceId id) inout
    {
        return workspaces[id].buffer.ptr;
    }

    private void displayBuffer(Buffer* buffer)
    {
        clearText(Attr(Colour.White, Colour.Black));
        enum contentStart = 1;
        enum contentHeight = TextModeHeight - contentStart;
        foreach (i; 0 .. min(workspaces.length, 9))
        {
            auto colour = i == activeWorkspace ? Colour.Yellow : Colour.Blue;
            writeText(Pos(cast(int) (i * 8), 0), Attr(Colour.Blue, colour), "******");
        }
        size_t firstLine = 0;
        auto count = buffer.lineCount;
        if (count > contentHeight)
        {
            firstLine = count - contentHeight;
        }
        foreach (i; 0 .. count)
        {
            auto line = buffer.line(firstLine + i);
            writeText(Pos(0, cast(int) (contentStart + i)), line[0 .. min($, TextModeWidth)]);
        }
        setTextCursorPos(Pos(0, 0));
    }

    void interact()
    {
        while (true)
        {
            displayBuffer(buffer(activeWorkspace));

            auto event = kbd.getEvent();
            if (event.type == KeyEvent.Type.Press)
            {
                if (event.key == Key.P)
                {
                    return;
                }
                foreach (i, k; [Key.N1, Key.N2, Key.N3, Key.N4, Key.N5, Key.N6, Key.N7, Key.N8, Key.N9])
                {
                    if (event.key == k && i < workspaces.length)
                    {
                        activeWorkspace = i;
                    }
                }
            }

            pause();
        }
    }
}
