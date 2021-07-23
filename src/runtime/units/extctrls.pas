unit ExtCtrls;

interface

uses
    Classes, Controls, Graphics;

type
    TImage = class(TControl)
    end;

    TTimer = class(TObject)
    public
        constructor Create; virtual;

    public
        Interval: Longint;
        Enabled: Boolean;
        OnTimer: TNotifyEvent;
    end;

    TShape = class(TObject)
    public
        Top: Integer;
        Left: Integer;
        Width: Integer;
        Height: Integer;
    end;

    TBevel = class(TObject)
    end;

implementation

constructor TTimer.Create;
begin
end;

end.
