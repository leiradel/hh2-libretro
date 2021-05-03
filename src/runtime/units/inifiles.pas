unit IniFiles;
interface

type
    TIniFile = class
    public
        constructor Create(FileName: string);
        function ReadInteger(section: string; key: string; default: integer): integer;
        function ReadBool(section: string; key: string; default: boolean): boolean;
        function ReadString(section: string; key: string; default: string): string;
    end;

implementation

constructor TIniFile.Create(FileName: string);
begin
end;

function TIniFile.ReadInteger(section: string; key: string; default: integer): integer;
begin
end;

function TIniFile.ReadBool(section: string; key: string; default: boolean): boolean;
begin
end;

function TIniFile.ReadString(section: string; key: string; default: string): string;
begin
end;

end.
