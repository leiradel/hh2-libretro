unit System;

interface

type
    HRESULT = Longint; // For Delphi compatibility
    Int8 = ShortInt;
    UInt8 = Byte;
    Int16 = SmallInt;
    UInt16 = Word;
    Int32 = Longint;
    UInt32 = LongWord;

    Integer = LongInt;
    Cardinal = LongWord;
    DWord = LongWord;
    SizeInt = NativeInt;
    SizeUInt = NativeUInt;
    PtrInt = NativeInt;
    PtrUInt = NativeUInt;
    ValSInt = NativeInt;
    ValUInt = NativeUInt;
    CodePointer = Pointer;
    ValReal = Double;
    Real = type Double;
    Extended = type Double;

    TDateTime = type double;
    TTime = type TDateTime;
    TDate = type TDateTime;

    Int64 = type NativeInt unimplemented; // only 53 bits at runtime
    UInt64 = type NativeUInt unimplemented; // only 52 bits at runtime
    QWord = type NativeUInt unimplemented; // only 52 bits at runtime
    Single = type Double unimplemented;
    Comp = type NativeInt unimplemented;
    NativeLargeInt = NativeInt;
    NativeLargeUInt = NativeUInt;

    UnicodeString = type String;
    WideString = type String;
    UnicodeChar = char;

    TObject = class
    end;

function ParamStr(Index: Integer): String;
function Trunc(X: Double): Integer;
function Round(X: Double): Integer; external name 'hh2.round';
procedure Randomize;
function Random(const ARange: Integer): Integer; overload; external name 'hh2.randomRange';
function Random: Double; overload; external name 'hh2.random';
function Odd(X: Integer): Boolean;

implementation

function ParamStr(Index: Integer): String; Assembler;
asm
    return "";
end;

function Trunc(X: Double): Integer; Assembler;
asm
    X = +X;
    if (!isFinite(X)) return X;
    return (X - X % X) || (X < 0 ? -0 : X === 0 ? X : 0);
end;

procedure Randomize;
begin
end;

function Odd(X: Integer): Boolean;
begin
    Odd := (X And 1) <> 0;
end;

end.
