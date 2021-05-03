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

procedure SetBackground(Image: TImage); assembler;
asm
    hh2.setBackground(Image);
end;

procedure AddGameScreen(Left, Top, Right, Bottom: Integer); assembler;
asm
    hh2.addGameScreen(Left, Top, Right, Bottom);
end;

procedure MapButton(Image: TImage; Button: RetropadButton); assembler;
asm
    hh2.mapButton(Image, Button);
end;

procedure MapTouch(Image: TImage; Left, Top, Right, Bottom: Integer; Caption: String); assembler;
asm
    hh2.mapTouch(Image, Left, Top, Right, Bottom, Caption);
end;

procedure AddUnmappedButton(Image: TImage; Caption: String); assembler;
asm
    hh2.AddUnmappedButton(Image, Caption);
end;

end.
