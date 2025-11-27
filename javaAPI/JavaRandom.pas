// This file is part of MicropolisD.

// MicropolisD is free software; you can redistribute it and/or modify
// it under the terms of the GNU lGPLv3,  lGPLv2.1


unit JavaRandom;

interface

type
TRandom = class(TObject)
constructor Create;
function NextInt(i:Integer):Integer;
function RInt64:Int64;

end;

implementation

constructor TRandom.Create;
begin
  inherited Create;
  Randomize;
end;

function TRandom.NextInt(i:Integer):Integer;
begin
  result:=Random(i);
end;

function TRandom.RInt64:Int64;
var lowerBits, upperBits: Int64;
begin
lowerBits := Random(MaxInt);
upperBits := Random(MaxInt) shl 32;
Result := upperBits or lowerBits;
end;


end.
