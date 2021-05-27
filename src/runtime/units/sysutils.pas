unit SysUtils;

interface

function FileExists(const FileName: String; FollowLink: Boolean = True): Boolean; external name 'hh2.fileExists';
function ExtractFilePath(const FileName: String): String;
function IncludeTrailingPathDelimiter(const S: String): String;
function StrToInt(const S: String): Integer;
function StrToIntDef(const S: String; Default: Integer): Integer;
function IntToStr(Value: Integer): String; external name 'String';
function Now: TDateTime;
procedure DecodeTime(const DateTime: TDateTime; var Hour, Min, Sec, MSec: Word);
procedure Beep;

implementation

uses
    Js;

function ExtractFilePath(const FileName: string): string;
begin
    ExtractFilePath := '';
end;

function IncludeTrailingPathDelimiter(const S: string): string;
begin
    IncludeTrailingPathDelimiter := '';
end;

function StrToInt(const S: String): Integer;
begin
    StrToInt := js.parseInt(S);
end;

function StrToIntDef(const S: String; Default: Integer): Integer;
begin
    if not js.isInteger(S) then
        StrToIntDef := Default
    else
        StrToIntDef := js.parseInt(S);
end;

function Now: TDateTime;
begin
end;

procedure DecodeTime(const DateTime: TDateTime; var Hour, Min, Sec, MSec: Word);
begin
end;

procedure Beep;
begin
end;

end.
