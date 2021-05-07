unit Classes;

interface

type
    TShiftState = set of (ssShift, ssAlt, ssCtrl, ssLeft, ssRight, ssMiddle, ssDouble, ssTouch, ssPen, ssCommand, ssHorizontal);

    TStrings = class
    public
        procedure Add(Item: String);
    end;

    TComponent = class
        constructor Create;
    end;

    TComponentClass = class of TComponent;

implementation

procedure TStrings.Add(Item: String);
begin
end;

constructor TComponent.Create;
begin
end;

end.
