unit HH2;

interface

uses
    ExtCtrls;

type
    RetropadButton = (Up, Down, Left, Right, A, B, X, Y, L, R, L2, R2, L3, R3, Select, Start);

procedure SetBackground(Image: TImage);
procedure AddGameScreen(Left, Top, Right, Bottom: Integer);
procedure MapButton(Image: TImage; Button: RetropadButton);
procedure MapTouch(Image: TImage; Left, Top, Right, Bottom: Integer; Caption: String);
procedure AddUnmappedButton(Image: TImage; Caption: String);

implementation

procedure SetBackground(Image: TImage);
begin
    asm
        hh2rt.setBackground(image);
    end;
end;

procedure AddGameScreen(Left, Top, Right, Bottom: Integer);
begin
    asm
        hh2rt.addGameScreen(left, top, right, bottom);
    end;
end;

procedure MapButton(Image: TImage; Button: RetropadButton);
begin
    asm
        hh2rt.mapButton(image, button);
    end;
end;

procedure MapTouch(Image: TImage; Left, Top, Right, Bottom: Integer; Caption: String);
begin
    asm
        hh2rt.mapTouch(image, left, top, right, bottom, caption);
    end;
end;

procedure AddUnmappedButton(Image: TImage; Caption: String);
begin
    asm
        hh2rt.addUnmappedButton(image, caption);
    end;
end;

end.
