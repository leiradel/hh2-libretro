unit IniFiles;
interface

type
    TIniFile = class
    public
        constructor Create(FileName: String);
        destructor Destroy;
        function ReadInteger(Section: String; Key: String; Default: Integer): Integer;
        function ReadBool(Section: String; Key: String; Default: Boolean): Boolean;
        function ReadString(Section: String; Key: String; Default: String): String;
    end;

implementation

constructor TIniFile.Create(FileName: String);
begin
end;

destructor TIniFile.Destroy;
begin
end;

function TIniFile.ReadInteger(Section: String; Key: String; Default: Integer): Integer;
begin
end;

function TIniFile.ReadBool(Section: String; Key: String; Default: Boolean): Boolean;
begin
end;

function TIniFile.ReadString(Section: String; Key: String; Default: String): String;
begin
end;

end.
