unit Registry;

interface

type
    TRegIniFile = class
    public
        constructor Create(FileName: String);
        destructor Destroy;
        function ReadInteger(Section: String; Key: String; Default: Integer): Integer;
        procedure WriteInteger(Section: String; Key: String; Val: Integer);
        function ReadBool(Section: String; Key: String; Default: Boolean): Boolean;
        procedure WriteBool(Section: String; Key: String; Val: Boolean);
    end;


implementation

constructor TRegIniFile.Create(FileName: String);
begin
end;

destructor TRegIniFile.Destroy;
begin
end;

function TRegIniFile.ReadInteger(Section: String; Key: String; Default: Integer): Integer;
begin
    ReadInteger := Default;
end;

procedure TRegIniFile.WriteInteger(Section: String; Key: String; Val: Integer);
begin
end;

function TRegIniFile.ReadBool(Section: String; Key: String; Default: Boolean): Boolean;
begin
    ReadBool := Default;
end;

procedure TRegIniFile.WriteBool(Section: String; Key: String; Val: Boolean);
begin
end;

end.
