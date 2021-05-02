unit Forms;

interface

uses
    Windows, Graphics;

type
    TCloseAction = (caNone, caHide, caFree, caMinimize);
    TPosition = (poDesigned, poDefault, poDefaultPosOnly, poDefaultSizeOnly, poScreenCenter, poDesktopCenter, poMainFormCenter, poOwnerFormCenter);
    TFormStyle = (fsNormal, fsMDIChild, fsMDIForm, fsStayOnTop);

    TForm = class
    public
        procedure close;

    public
        Handle: HWND;
        Position: TPosition;
        FormStyle: TFormStyle;
        DoubleBuffered: boolean;
        Top: Integer;
        Left: Integer;
        Width: Integer;
        Height: Integer;
        ClientWidth: Integer;
        ClientHeight: Integer;
        Color: TColor;
        TransparentColor: boolean;
        TransparentColorValue: TColor;
        Enabled: boolean;
    end;

    TApplication = class
    public
        procedure Terminate;

    public
        Title: string;
    end;

    TScreen = class
    public
        Width: Integer;
        Height: Integer;
    end;

var
    Application: TApplication;
    Screen: TScreen;

implementation

procedure TForm.close;
begin
end;

procedure TApplication.Terminate;
begin
end;

end.
