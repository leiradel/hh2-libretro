unit SysUtils;

interface

function FileExists(const FileName: String; FollowLink: Boolean = True): Boolean;
function ExtractFilePath(const FileName: String): String;
function IncludeTrailingPathDelimiter(const S: String): String;
function StrToInt(const S: String): Integer;
function StrToIntDef(const S: String; Default: Integer): Integer;
function IntToStr(Value: Integer): String;
function Now: TDateTime;
procedure Beep;

implementation

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
    asm
        return tonumber(s)
    end;
end;

function StrToIntDef(const S: String; Default: Integer): Integer;
begin
    asm
        return tonumber(s) or default
    end;
end;

function Now: TDateTime;
begin
    asm
        local _, clock = hh2rt.now()
        return clock
    end;
end;

procedure Beep;
begin
end;

end.
