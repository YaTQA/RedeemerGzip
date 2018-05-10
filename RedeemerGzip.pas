unit RedeemerGzip;

// Konvertiert einen GZIP-Stream in einen ZLIB-Stream
// RFC 1952

interface

uses
  Classes, SysUtils;

type TGzipOS = (osFAT         = 0,
                osAmiga       = 1,
                osVMS         = 2,
                osUnix        = 3,
                osVMCMS       = 4,
                osAtariTOS    = 5,
                osHPFS        = 6,
                osMac         = 7,
                osZ           = 8,
                osCPM         = 9,
                osTOPS20      = 10,
                osNTFS        = 11,
                osQDOS        = 12,
                osAcornRISCOS = 13,
                osUnknown     = 255);

type
  TRedeemerGzipDecompressionAdapter = class
    public
      constructor Create(From: TStream);
      destructor Destroy(); override;
      const
        ID1: Byte = 31; // Header
        ID2: Byte = 139; // Header
        CompressionMethod: Byte = 8; // Deflate
      var
        IsText, HasHeaderCRC, HasExtra, HasName, HasComment: Boolean;
        Timestamp: Cardinal;
        CompressionLevel: Byte; // 2 = max, 4 = so lala
        OS: TGzipOS;
        ExtraLen: Word;
        Extra: TBytes;
        Name, Comment: WideString;
        HeaderCRC: Word;
        Zlib: TMemoryStream;
        UncompressedCRC32: Cardinal;
        UncompressedSize: Cardinal;
  end;

implementation

{ TRedeemerGzipAdapter }

constructor TRedeemerGzipDecompressionAdapter.Create(From: TStream);
function ReadByte: Byte;
begin
  From.Read(Result, 1);
end;
procedure ReadStr(out s: WideString);
var
  Temp: Byte;
begin
  s := '';
  repeat
    Temp := ReadByte;
    if Temp = 0 then
    Exit
    else
    s := s + WideChar(Temp); // Konvertiere ISO 8859-1 nach UTF-16
  until False;
end;
var
  Temp: Byte;
function ReadBool: Boolean;
begin
  Result := Temp mod 2 = 1;
  Temp := Temp shr 1;
end;
begin
  inherited Create;

  if (ReadByte <> ID1)
  or (ReadByte <> ID2)
  or (ReadByte <> CompressionMethod) then
  raise Exception.Create('Data error.');

  // Flags
  Temp := ReadByte;
  IsText := ReadBool;
  HasHeaderCRC := ReadBool;
  HasExtra := ReadBool;
  HasName := ReadBool;
  HasComment := ReadBool;

  // Sonstiger fixer Header
  From.Read(Timestamp, 4);
  CompressionLevel := ReadByte;
  From.Read(OS, 1);

  // Optionaler Header
  if HasExtra then
  begin
    From.Read(ExtraLen, 2);
    SetLength(Extra, ExtraLen);
    From.Read(Extra[0], ExtraLen);
  end;
  if HasName then
  ReadStr(Name);
  if HasComment then
  ReadStr(Comment);
  if HasHeaderCRC then
  From.Read(HeaderCRC, 2);

  Zlib := TMemoryStream.Create;
  try
    // Zlib-Header erstellen
    Temp := $78;
    Zlib.Write(Temp, 1);
    //if CompressionLevel = 4 then
    Temp := $9c; // tatsächlicher Level interessiert kein Schwein
    //else
    //Temp := $da;
    Zlib.Write(Temp, 1);

    // Zlib-Daten kopieren (ohne CRC32, denn das irritiert Zlib, da dessen CRC offenbar anders ist)
    Zlib.CopyFrom(From, From.Size - From.Position - 8);
    Zlib.Position := 0;

    From.Read(UncompressedCRC32, 4);
    From.Read(UncompressedSize, 4);
  except
    Zlib.Free;
    raise;
  end;
end;

destructor TRedeemerGzipDecompressionAdapter.Destroy;
begin
  inherited;
  Zlib.Free;
end;

end.
