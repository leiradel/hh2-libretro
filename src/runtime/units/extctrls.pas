unit ExtCtrls;

interface

uses
    Classes, Controls, Graphics;

type
    TImage = class(TControl)
    public
        constructor Create; virtual;

    public
        Picture: TPicture;
        Stretch: Boolean;
        AutoSize: Boolean;
        Center: Boolean;
        Transparent: Boolean;
    end;

    TTimer = class
    public
        constructor Create; virtual;

    public
        Interval: Longint;
        Enabled: Boolean;
        OnTimer: TNotifyEvent;
    end;

    TShape = class
    public
        Top: Integer;
        Left: Integer;
        Width: Integer;
        Height: Integer;
    end;

    TBevel = class
    end;

implementation

constructor TImage.Create;
begin
end;

constructor TTimer.Create;
begin
end;

end.
