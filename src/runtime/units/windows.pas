unit Windows;

interface

const
    VK_ESCAPE = $1B;
    VK_LEFT = $25;
    VK_RIGHT = $27;
    VK_RETURN = $0D;

    SW_HIDE = 0;
    SW_MAXIMIZE = 3;
    SW_MINIMIZE = 6;
    SW_RESTORE = 9;
    SW_SHOW = 5;
    SW_SHOWDEFAULT = 10;
    SW_SHOWMAXIMIZED = 3;
    SW_SHOWMINIMIZED = 2;
    SW_SHOWMINNOACTIVE = 7;
    SW_SHOWNA = 8;
    SW_SHOWNOACTIVATE = 4;
    SW_SHOWNORMAL = 1;

type
    HINSTANCE = longint;
    HWND = longint;

function ShellExecute(wnd: HWND; lpOperation: string; lpFile: string; lpParameters: longint; lpDirectory: string; nShowCmd: integer): HINSTANCE;

implementation

function ShellExecute(wnd: HWND; lpOperation: string; lpFile: string; lpParameters: longint; lpDirectory: string; nShowCmd: integer): HINSTANCE;
begin
    ShellExecute := 0;
end;

end.
