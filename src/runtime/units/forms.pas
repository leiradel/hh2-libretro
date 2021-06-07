unit Forms;

interface

uses
    Classes, Controls, Graphics, Types, Windows;

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

    TCustomForm = class(TControl) {HACK not really true but enough to get us going without mimicking the entire inheritance tree}
    public
        constructor Create; virtual;

    public
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

    TScreen = class
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
    asm
        hh2.print("TForm.TCustomForm FUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU");
        const $mod = pas.hh2dfm;
        hh2.print('################################ ', mod);
    end;
end;

constructor TForm.Create;
begin
    asm
        hh2.print("TForm.Create FUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU");
    end;

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

procedure TApplication.CreateForm(InstanceClass: TComponentClass; var Reference: TForm);
begin
    Reference := InstanceClass.Create;

    asm
        const instance = reference.get();

        if (instance['$classname'] == 'tform1') {
            InitTForm1(Reference);
        }
    end;

    TForm(Reference).OnCreate(nil);

    if not HasMainForm then
    begin
        MainForm := TForm(Reference);
        HasMainForm := True;
    end;
end;

initialization
    Application := TApplication.Create;
end.
