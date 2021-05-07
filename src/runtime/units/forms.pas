unit Forms;

interface

uses
    Classes, Windows, Graphics;

type
    TCloseAction = (caNone, caHide, caFree, caMinimize);
    TFormStyle = (fsNormal, fsMDIChild, fsMDIForm, fsStayOnTop);

    TPosition = (
        poDesigned, poDefault, poDefaultPosOnly, poDefaultSizeOnly, poScreenCenter, poDesktopCenter, poMainFormCenter,
        poOwnerFormCenter
    );

    TCustomForm = class(TComponent) {HACK not really true but enough to get us going without mimicking the entire inheritance tree}
    public
        constructor Create;
    end;

    TForm = class(TCustomForm)
    public
        procedure Close;

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

    TApplication = class(TComponent)
    public
        constructor Create;
        procedure Initialize;
        procedure Run;
        procedure Terminate;
        procedure CreateForm(InstanceClass: TComponentClass; var Reference);

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

constructor TCustomForm.Create; assembler;
asm
    throw "Initialize properties with the contents of the DFM file";
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
end;

procedure TApplication.Terminate;
begin
end;

procedure TApplication.CreateForm(InstanceClass: TComponentClass; var Reference);
begin
    Reference := InstanceClass.Create();

    asm
    end;

    if not HasMainForm then
    begin
        MainForm := TForm(Reference);
        HasMainForm := True;
    end;
end;

end.
