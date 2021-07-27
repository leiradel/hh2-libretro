unit Graphics;

interface

const
    ANSI_CHARSET = 0;
    DEFAULT_CHARSET = 1;
    SYMBOL_CHARSET = 2;
    MAC_CHARSET = 77;
    SHIFTJIS_CHARSET = 128;
    HANGEUL_CHARSET = 129;
    JOHAB_CHARSET = 130;
    GB2312_CHARSET = 134;
    CHINESEBIG5_CHARSET = 136;
    GREEK_CHARSET = 161;
    TURKISH_CHARSET = 162;
    VIETNAMESE_CHARSET = 163;
    HEBREW_CHARSET = 177;
    ARABIC_CHARSET = 178;
    BALTIC_CHARSET = 186;
    RUSSIAN_CHARSET = 204;
    THAI_CHARSET = 222;
    EASTEUROPE_CHARSET = 238;
    OEM_CHARSET = 255 ;

type
    TColor = -2147483648..2147483647;
    TPenStyle = (psSolid, psDash, psDot, psDashDot, psDashDotDot, psClear, psInsideFrame, psUserStyle, psAlternate);
    TFontCharset = Byte;
    TFontStyle = (fsBold, fsItalic, fsUnderline, fsStrikeOut);
    TFontStyles = set of TFontStyle;

    TPen = class(TObject)
    public
        Color: TColor;
        Style: TPenStyle;
    end;

    TBrush = class(TObject)
    public
        Color: TColor;
    end;

    TCanvas = class(TObject)
    public
        procedure Rectangle(X1, Y1, X2, Y2: Integer);

    public
        Pen: TPen;
        Brush: TBrush;
    end;

    TBitmap = class(TObject)
    public
        constructor Create;

    public
        Width: integer;
        Height: integer;
        Canvas: TCanvas;
    end;

    TPicture = class(TObject)
    public
        procedure LoadFromFile(const Filename: String);
    end;

    TFont = class(TObject)
    public
        Color: TColor;
        Charset: TFontCharset;
        Height: Integer;
        Name: String;
        Style: TFontStyles;
    end;

const
    clAqua = 0;
    clBackground = 0;
    clBlack = 0;
    clActiveCaption = 0;
    clBlue = 0;
    clInactiveCaption = 0;
    clCream = 0;
    clMenu = 0;
    clDkGray = 0;
    clWindow = 0;
    clFuchsia = 0;
    clWindowFrame = 0;
    clGray = 0;
    clMenuText = 0;
    clGreen = 0;
    clWindowText = 0;
    clLime = 0;
    clCaptionText = 0;
    clLtGray = 0;
    clActiveBorder = 0;
    clMaroon = 0;
    clInactiveBorder = 0;
    clMedGray = 0;
    clAppWorkSpace = 0;
    clMoneyGreen = 0;
    clHighlight = 0;
    clNavy = 0;
    clHighlightText = 0;
    clOlive = 0;
    clBtnFace = 0;
    clPurple = 0;
    clBtnShadow = 0;
    clRed = 0;
    clGrayText = 0;
    clSilver = 0;
    clBtnText = 0;
    clSkyBlue = 0;
    clInactiveCaptionText = 0;
    clTeal = 0;
    clBtnHighlight = 0;
    clWhite = 0;
    cl3DDkShadow = 0;
    clYellow = 0;
    cl3DLight = 0;
    clInfoText = 0;
    clInfoBk = 0;
    clGradientActiveCaption = 0;
    clGradientInactiveCaption = 0;
    clDefault  = 0;

implementation

procedure TCanvas.Rectangle(X1, Y1, X2, Y2: Integer);
begin
end;

constructor TBitmap.Create;
begin
    asm
    end;
end;

end.
