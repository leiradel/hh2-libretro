unit Menus;

interface

uses
    Classes;

type
    TMenuAutoFlag = (maAutomatic, maManual, maParent);

    TPopupMenu = class
    public
        constructor Create;

    public
        AutoHotkeys: TMenuAutoFlag;
        OnPopup: TNotifyEvent;
    end;

    TMenuItem = class
    public
        constructor Create;

    public
        Checked: Boolean;
        Caption: String;
        Default: Boolean;
        ShortCut: TShortCut;
    end;

implementation

constructor TPopupMenu.Create;
begin
end;

constructor TMenuItem.Create;
begin
end;

end.