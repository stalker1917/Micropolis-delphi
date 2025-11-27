unit Resources;

interface
uses System.IniFiles;
var IsInit:Boolean=False;
MainWindowStrings,CityMessages,StatusMessages,GuiStrings : TIniFile;


procedure InitResources;
function GetGuiString(S:String):String;
function GetPackageVersion:String;

implementation
procedure InitResources;
begin
 if IsInit then exit;
 IsInit := True;
 MainWindowStrings := TIniFile.Create('./strings/MainWindowStrings.properties');
 CityMessages := TIniFile.Create('./strings/CityMessages.properties');
 StatusMessages := TIniFile.Create('./strings/StatusMessages.properties');
 GuiStrings := TIniFile.Create('./strings/GuiStrings.properties') //properties');
end;

function GetGuiString(S:String):String;
begin
  Result := GuiStrings.ReadString('Main',S,'');
  // Result := GuiStrings.ReadString('Main','menu.game','');

end;

function GetPackageVersion:String;
begin
  result := 'Version Beta(0.7)';
end;

end.
