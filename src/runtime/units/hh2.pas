unit HH2;

interface

uses
    ExtCtrls;

type
    RetropadButton = (Up, Down, Left, Right, A, B, X, Y, L, R, L2, R2, L3, R3, Select, Start);

procedure SetBackground(Image: TImage); external name 'hh2.setBackground';
procedure AddGameScreen(Left, Top, Right, Bottom: Integer); external name 'hh2.addGameScreen';
procedure MapButton(Image: TImage; Button: RetropadButton); external name 'hh2.mapButton';
procedure MapTouch(Image: TImage; Left, Top, Right, Bottom: Integer; Caption: String); external name 'hh2.mapTouch';
procedure AddUnmappedButton(Image: TImage; Caption: String); external name 'hh2.AddUnmappedButton';

implementation

end.
