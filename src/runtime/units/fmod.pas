unit Fmod;

interface

uses
    Fmodtypes;

function FSOUND_Init(mixrate: integer; maxsoftwarechannels: integer; flags: cardinal): shortint;
function FSOUND_SetOutput(outputtype: integer): shortint;
function FSOUND_Sample_Load(index: integer; name_or_data: string; inputmode: cardinal; offset: integer; length: integer): PFSOUND_SAMPLE;
procedure FSOUND_Sample_Free(sound: PFSOUND_SAMPLE);
procedure FSOUND_Close;
procedure FSOUND_PlaySound(channel: integer; sound: PFSOUND_SAMPLE);
procedure FSOUND_StopSound(channel: integer);

implementation

function FSOUND_Init(mixrate: integer; maxsoftwarechannels: integer; flags: cardinal): shortint;
begin
    FSOUND_Init := 0;
end;

function FSOUND_SetOutput(outputtype: integer): shortint;
begin
    FSOUND_SetOutput := 0;
end;

function FSOUND_Sample_Load(index: integer; name_or_data: string; inputmode: cardinal; offset: integer; length: integer): PFSOUND_SAMPLE;
begin
    FSOUND_Sample_Load := 0;
end;

procedure FSOUND_Sample_Free(sound: PFSOUND_SAMPLE);
begin
end;

procedure FSOUND_Close;
begin
end;

procedure FSOUND_PlaySound(channel: integer; sound: PFSOUND_SAMPLE);
begin
end;

procedure FSOUND_StopSound(channel: integer);
begin
end;

end.
