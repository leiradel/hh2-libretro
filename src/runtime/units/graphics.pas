unit Graphics;

interface

type
    TColor = -2147483648..2147483647;
    TPenStyle = (psSolid, psDash, psDot, psDashDot, psDashDotDot, psClear, psInsideFrame, psUserStyle, psAlternate);

    TPen = class
    public
        Color: TColor;
        Style: TPenStyle;
    end;

    TBrush = class
    public
        Color: TColor;
    end;

    TCanvas = class
    public
        procedure Rectangle(X1, Y1, X2, Y2: Integer);

    public
        Pen: TPen;
        Brush: TBrush;
    end;

    TBitmap = class
    public
        Width: integer;
        Height: integer;
        Canvas: TCanvas;
    end;

    TPicture = class
    public
        procedure LoadFromFile(const Filename: string); virtual;

    public
        Bitmap: TBitmap;
    end;

implementation

procedure TCanvas.Rectangle(X1, Y1, X2, Y2: Integer);
begin
end;

procedure TPicture.LoadFromFile(const Filename: string);
begin
end;

end.
