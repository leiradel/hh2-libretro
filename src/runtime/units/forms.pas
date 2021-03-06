unit Forms;

interface

uses
    Classes, Controls, Graphics, Windows;

type
    TCloseAction = (caNone, caHide, caFree, caMinimize);
    TFormStyle = (fsNormal, fsMDIChild, fsMDIForm, fsStayOnTop);
    TBorderIcon = (biSystemMenu, biMinimize, biMaximize, biHelp);
    TBorderIcons = set of TBorderIcon;
    TFormBorderStyle = (bsDialog, bsSingle, bsNone, bsSizeable, bsToolWindow, bsSizeToolWin);
    TPrintScale = (poNone, poProportional, poPrintToFit);

    TPosition = (
        poDesigned, poDefault, poDefaultPosOnly, poDefaultSizeOnly, poScreenCenter, poDesktopCenter, poMainFormCenter,
        poOwnerFormCenter
    );

    TCloseEvent = procedure(Sender: TObject; var Action: TCloseAction) of object;

    TControlScrollBar = class
    public
        constructor Create; virtual;

    public
        Visible: Boolean;
    end;

    TCustomForm = class(TControl) {HACK not really true but enough to get us going without mimicking the entire inheritance tree}
    public
        constructor Create; virtual;

    public
        OnCreate: TNotifyEvent;
        OnClose: TCloseEvent;
        FormStyle: TFormStyle;
        TransparentColor: Boolean;
        TransparentColorValue: TColor;
        BorderIcons: TBorderIcons;
        BorderStyle: TFormBorderStyle;
        KeyPreview: Boolean;
        OldCreateOrder: Boolean;
        PrintScale: TPrintScale;
        Scaled: Boolean;
        PixelsPerInch: Integer;
    end;

    TForm = class(TCustomForm)
    public
        constructor Create; virtual;
        procedure Close;

    public
        Handle: HWND;
        Position: TPosition;
        DoubleBuffered: Boolean;
        TextHeight: Integer;
        HorzScrollBar: TControlScrollBar;
        VertScrollBar: TControlScrollBar;
    end;

    TApplication = class(TComponent)
    public
        constructor Create; virtual;
        procedure Initialize;
        procedure Run;
        procedure Terminate;

    public
        MainForm: TForm;
        Title: string;

    private
        HasMainForm: Boolean;
    end;

    TScreen = class(TObject)
    public
        Width: Integer;
        Height: Integer;
    end;

var
    Application: TApplication;
    Screen: TScreen;

implementation

constructor TCustomForm.Create;
begin
end;

constructor TForm.Create;
begin
    inherited Create;
end;

procedure TForm.Close;
begin
end;

constructor TApplication.Create;
begin
    inherited Create;
    HasMainForm := False;
end;

procedure TApplication.Initialize;
begin
end;

procedure TApplication.Run;
begin
    asm
        rtl.hh2main.setup();
    end;
end;

procedure TApplication.Terminate;
begin
end;

initialization
    Application := TApplication.Create();
    Screen := TScreen.Create();
end.
