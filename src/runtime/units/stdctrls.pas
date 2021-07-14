unit StdCtrls;

interface

uses
    Classes, Controls, Graphics;

type
    TComboBoxStyle = (csDropDown, csSimple, csDropDownList, csOwnerDrawFixed, csOwnerDrawVariable);

    TLabel = class(TControl)
    public
        constructor Create; virtual;

    public
        Caption: String;
        Alignment: TAlignment;
        AutoSize: Boolean;
        ParentFont: Boolean;
        Transparent: Boolean;
    end;

    TComboBox = class(TObject)
    public
        procedure SetFocus;
        procedure Clear;

    public
        ItemIndex: Integer;
        ItemHeight: Integer;
        Text: String;
        Items: TStrings;
        Style: TComboBoxStyle;
    end;

    TCheckBox = class(TObject)
    public
        Checked: Boolean;
    end;

    TButton = class(TObject)
    public
        Enabled: Boolean;
    end;

implementation

constructor TLabel.Create;
begin
    inherited Create;
end;

procedure TComboBox.SetFocus;
begin
end;

procedure TComboBox.Clear;
begin
end;

end.
