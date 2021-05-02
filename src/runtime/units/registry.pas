unit Registry;

interface

type
    TRegIniFile = class
    public
        constructor Create(FileName: string);
        function ReadInteger(section: string; key: string; default: integer): integer;
        procedure WriteInteger(section: string; key: string; val: integer);
        function ReadBool(section: string; key: string; default: boolean): boolean;
        procedure WriteBool(section: string; key: string; val: boolean);
    end;


implementation

constructor TRegIniFile.Create(FileName: string);
begin
end;

function TRegIniFile.ReadInteger(section: string; key: string; default: integer): integer;
begin
end;

procedure TRegIniFile.WriteInteger(section: string; key: string; val: integer);
begin
end;

function TRegIniFile.ReadBool(section: string; key: string; default: boolean): boolean;
begin
end;

procedure TRegIniFile.WriteBool(section: string; key: string; val: boolean);
begin
end;

end.
