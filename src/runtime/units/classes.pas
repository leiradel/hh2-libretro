unit Classes;

interface

type
    TShiftState = set of (ssShift, ssAlt, ssCtrl, ssLeft, ssRight, ssMiddle, ssDouble, ssTouch, ssPen, ssCommand, ssHorizontal);
    TAlignment = (taLeftJustify, taRightJustify, taCenter);
    TShortCut = Word;
    TNotifyEvent = procedure(Sender: TObject) of object;

    TStrings = class
    public
        procedure Add(Item: String);
    end;

    TComponent = class
        constructor Create; virtual;
    end;

implementation

procedure TStrings.Add(Item: String);
begin
end;

constructor TComponent.Create;
begin
end;

end.
