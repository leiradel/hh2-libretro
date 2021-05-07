unit StdCtrls;

interface

uses
    Classes, Graphics;

type
    TLabel = class
    public
        Caption: string;
        Top: Integer;
        Left: Integer;
        Width: Integer;
        Height: Integer;
        Visible: Boolean;
        Font: TFont;
    end;

    TComboBox = class
    public
        procedure SetFocus;
        procedure Clear;

    public
        ItemIndex: Integer;
        Text: String;
        Items: TStrings;
    end;

    TCheckBox = class
    public
        Checked: Boolean;
    end;

    TButton = class
    public
        Enabled: Boolean;
    end;

implementation

procedure TComboBox.SetFocus;
begin
end;

procedure TComboBox.Clear;
begin
end;

end.
