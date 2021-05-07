unit Fmod;

interface

uses
    Fmodtypes;

function FSOUND_Init(MixRate: Integer; MaxSoftwareChannels: Integer; Flags: Cardinal): Shortint;
function FSOUND_SetOutput(OutputType: Integer): Shortint;
function FSOUND_Sample_Load(Index: Integer; NameOrData: String; InputMode: Cardinal; Offset: Integer; Length: Integer): PFSOUND_SAMPLE;
procedure FSOUND_Sample_Free(Sound: PFSOUND_SAMPLE);
procedure FSOUND_Close;
procedure FSOUND_PlaySound(Channel: Integer; Sound: PFSOUND_SAMPLE);
procedure FSOUND_StopSound(Channel: Integer);

implementation

function FSOUND_Init(MixRate: Integer; MaxSoftwareChannels: Integer; Flags: Cardinal): Shortint;
begin
    FSOUND_Init := 0;
end;

function FSOUND_SetOutput(OutputType: Integer): Shortint;
begin
    FSOUND_SetOutput := 0;
end;

function FSOUND_Sample_Load(Index: Integer; NameOrData: String; InputMode: Cardinal; Offset: Integer; Length: Integer): PFSOUND_SAMPLE;
begin
    FSOUND_Sample_Load := 0;
end;

procedure FSOUND_Sample_Free(Sound: PFSOUND_SAMPLE);
begin
end;

procedure FSOUND_Close;
begin
end;

procedure FSOUND_PlaySound(Channel: Integer; Sound: PFSOUND_SAMPLE);
begin
end;

procedure FSOUND_StopSound(Channel: Integer);
begin
end;

end.
