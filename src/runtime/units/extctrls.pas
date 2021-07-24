unit ExtCtrls;

interface

uses
    Classes, Controls, Graphics;

type
    TImage = class(TControl)
    public
        constructor Create; virtual;

    public
        Stretch: Boolean;
        AutoSize: Boolean;
        Center: Boolean;
        Transparent: Boolean;
        Picture: TPicture;
    end;

    TTimer = class(TObject)
    public
        constructor Create; virtual;

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

constructor TImage.Create;
begin
    Picture := TPicture.Create();

    asm
        hh2rt.images[self] = true
    end;
end;

constructor TTimer.Create;
begin
    asm
        hh2rt.timers[self] = true
    end;
end;

end.
