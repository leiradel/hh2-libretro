unit ExtCtrls;

interface

uses
    Classes, Controls, Graphics;

type
    TImage = class(TControl)
    public
        Stretch: Boolean;
        AutoSize: Boolean;
        Center: Boolean;
        Transparent: Boolean;
        Picture: TPicture;
    end;

    TTimer = class(TObject)
    public
        Interval: Longint;
        Expiration: Longint;
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

end.
