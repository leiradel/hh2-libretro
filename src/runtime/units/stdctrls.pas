unit StdCtrls;

interface

uses
    Classes;

type
    TLabel = class
    public
        Caption: string;
    end;

    TComboBox = class
    public
        procedure SetFocus;

    public
        ItemIndex: integer;
        Text: string;
        Items: TStrings;
    end;

    TCheckBox = class
    public
        Checked: boolean;
    end;

    TButton = class
    end;

implementation

procedure TComboBox.SetFocus;
begin
end;

end.
