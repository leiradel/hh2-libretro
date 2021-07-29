unit System;

interface

type
    TObject = class
    public
        constructor Create; virtual;
    end;

    TDateTime = longint;

function ParamStr(Index: Integer): String;
function Chr(X: Byte): Char;
procedure Randomize;
function Ord(X: Ordinal): Byte;
function Odd(X: Integer): Boolean;
function Round(X: Real): Integer;
function Random(const ARange: Integer): Integer;
function Trunc(X: Real): Integer;

implementation

constructor TObject.Create;
begin
end;

function ParamStr(Index: Integer): String;
begin
    ParamStr := '';
end;

function Chr(X: Byte): Char;
begin
    asm
        return string.char(x)
    end;
end;

procedure Randomize;
begin
    asm
        math.randomseed()
    end;
end;

function Ord(X: Ordinal): Byte;
begin
    asm
        local t = type(x)

        if t == 'string' then
            return str.byte(x)
        elseif t == 'boolean' then
            return x and 1 or 0
        else
            error(string.format("don't know how to apply Ord to %s", t))
        end
    end;
end;

function Odd(X: Integer): Boolean;
begin
    asm
        return (x % 2) == 1
    end;
end;

function Round(X: Real): Integer;
begin
    asm
        local int, frac = math.modf(x)

        if frac < 0.5 then
            return int
        elseif frac > 0.5 then
            return int + 1
        else
            return int + (int % 2)
        end
    end;
end;

function Random(const ARange: Integer): Integer;
begin
    asm
        return math.random(arange) - 1
    end;
end;

function Trunc(X: Real): Integer;
begin
    asm
        return math.floor(X)
    end;
end;

end.
