unit ExtCtrls;

interface

uses
    Graphics;

type
    TImage = class
    public
        Picture: TPicture;
        Visible: boolean;
        Enabled: boolean;
        Stretch: boolean;
        AutoSize: boolean;
        Left: integer;
        Top: integer;
        Width: integer;
        Height: integer;
        Hint: string;
    end;

    TTimer = class
    public
        Interval: longint;
        Enabled: boolean;
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

end.
