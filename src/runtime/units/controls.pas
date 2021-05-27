unit Controls;

interface

uses
    Classes, Graphics, Menus;

const
    crDefault = 0;
    crArrow = -2;
    crCross = -3;
    crIBeam = -4;
    crSizeNESW = -6;
    crSizeNS = -7;
    crSizeNWSE = -8;
    crSizeWE = -9;
    crUpArrow = -10;
    crHourGlass = -11;
    crDrag = -12;
    crNoDrop = -13;
    crHSplit = -14;
    crVSplit = -15;
    crMultiDrag = -16;
    crSQLWait = -17;
    crNo = -18;
    crAppStart = -19;
    crHelp = -20;
    crHandPoint = -21;
    crSizeAll = -22;

type
    TAnchorKind = (akTop, akLeft, akRight, akBottom);
    TAnchors = set of TAnchorKind;
    TMouseButton = (mbLeft, mbRight, mbMiddle);
    TCursor = -32768..32767;

    TKeyEvent = procedure(Sender: TObject; var Key: Word; Shift: TShiftState) of object;
    TMouseEvent = procedure(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer) of object;
    TMouseMoveEvent = procedure(Sender: TObject; Shift: TShiftState; X, Y: Integer) of object;

    TControl = class(TComponent)
    public
        constructor Create; virtual;

    public
        OnMouseUp: TMouseEvent;
        OnMouseDown: TMouseEvent;
        OnActivate: TNotifyEvent;
        OnCreate: TNotifyEvent;
        OnKeyDown: TKeyEvent;
        OnKeyUp: TKeyEvent;
        OnMouseMove: TMouseMoveEvent;
        OnClick: TNotifyEvent;
        Cursor: TCursor;
        ParentShowHint: Boolean;
        ShowHint: Boolean;
        ParentColor: Boolean;
        Visible: Boolean;
        Enabled: Boolean;
        Left: Integer;
        Top: Integer;
        Width: Integer;
        Height: Integer;
        Hint: String;
        Anchors: TAnchors;
        ClientWidth: Integer;
        ClientHeight: Integer;
        Color: TColor;
        Font: TFont;
        PopupMenu: TPopupMenu;
        Caption: String;
    end;

implementation

constructor TControl.Create;
begin
end;

end.
