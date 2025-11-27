unit Animation;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  TileImage, 
  LoaderContext,
  Xml.XMLDoc, Xml.XMLIntf, // for XML parsing
  Graphics; // for drawing, if needed

type
  // Forward declaration
  TAnimation = class;

  // Frame class implementing IPart
  TAnimationFrame = class(TInterfacedObject, ITileImagePart)
  private
    FFrame: TTileImage;
    FDuration: Integer;
  public
    constructor Create(AFrame: TTileImage; ADuration: Integer);
    function GetImage: TTileImage;

    property Frame: TTileImage read FFrame;
    property Duration: Integer read FDuration;
  end;

  // Animation class, inherits TileImage and implements IMultiPart
  TAnimation = class(TTileImage, IMultiPart)
  private
    const
      DEFAULT_DURATION = 125;
  private
    FFrames: TObjectList<TAnimationFrame>;
    FTotalDuration: Integer;

    procedure LoadFromXML(const XMLNode: IXMLNode; const Context: TLoaderContext);
    function GetDefaultImage: TTileImage;
  public
    constructor Create;
    destructor Destroy; override;

    class function Load(const AniFileName: string; const Context: TLoaderContext): TAnimation;

    // IMultiPart interface
    function MakeEmptyCopy: IMultiPart;
    function Parts: TEnumerable<ITileImagePart>;
    procedure AddPartLike(Image: TTileImage; RefPart: ITileImagePart);
    function AsTileImage: TTileImage;

    procedure AddFrame(Image: TTileImage; Duration: Integer);
    function GetFrameByTime(ACycle: Integer): TTileImage;

    procedure DrawFragment(Gr: TCanvas; DestX, DestY, SrcX, SrcY: Integer); override;

    property TotalDuration: Integer read FTotalDuration;
    property Frames: TObjectList<TAnimationFrame> read FFrames;
  end;

implementation

uses
  System.StrUtils, Xml.XMLDoc, Xml.XMLIntf, System.Math;

{ TAnimationFrame }

constructor TAnimationFrame.Create(AFrame: TTileImage; ADuration: Integer);
begin
  inherited Create;
  FFrame := AFrame;
  FDuration := ADuration;
end;

function TAnimationFrame.GetImage: TTileImage;
begin
  Result := FFrame;
end;

{ TAnimation }

constructor TAnimation.Create;
begin
  inherited Create;
  FFrames := TObjectList<TAnimationFrame>.Create(True); // owns objects
  FTotalDuration := 0;
end;

destructor TAnimation.Destroy;
begin
  FFrames.Free;
  inherited;
end;

class function TAnimation.Load(const AniFileName: string; const Context: TLoaderContext): TAnimation;
var
  XMLDoc: IXMLDocument;
  RootNode: IXMLNode;
  Animation: TAnimation;
begin
  Animation := nil;
  XMLDoc := TXMLDocument.Create(nil);
  try
    XMLDoc.LoadFromFile(AniFileName);
    XMLDoc.Active := True;
    RootNode := XMLDoc.DocumentElement;

    if (RootNode = nil) or (RootNode.NodeName <> 'micropolis-animation') then
      raise Exception.Create('Unrecognized file format');

    Animation := TAnimation.Create;
    Animation.LoadFromXML(RootNode, Context);

    Result := Animation;
  except
    on E: Exception do
    begin
      Animation.Free;
      raise Exception.CreateFmt('%s: %s', [AniFileName, E.Message]);
    end;
  end;
end;

procedure TAnimation.LoadFromXML(const XMLNode: IXMLNode; const Context: TLoaderContext);
var
  ChildNode: IXMLNode;
  DurationStr: string;
  Duration: Integer;
  FrameImage: TTileImage;
begin
  for ChildNode in XMLNode.ChildNodes do
  begin
    if ChildNode.NodeType <> ntElement then
      Continue;

    if SameText(ChildNode.NodeName, 'frame') then
    begin
      DurationStr := ChildNode.Attributes['duration'];
      if DurationStr <> '' then
        Duration := StrToIntDef(DurationStr, DEFAULT_DURATION)
      else
        Duration := DEFAULT_DURATION;

      // Assume TileImage has a method to read from XML node and context
      FrameImage := TTileImage.ReadTileImageM(ChildNode, Context);
      AddFrame(FrameImage, Duration);
    end
    else
    begin
      // Unrecognized element, skip or ignore
      // No direct equivalent of skipToEndElement needed here since we're iterating children
    end;
  end;
end;

function TAnimation.MakeEmptyCopy: IMultiPart;
begin
  Result := TAnimation.Create;
end;

function TAnimation.Parts: TEnumerable<ITileImagePart>;
var
  List: TList<ITileImagePart>;
  Frame: TAnimationFrame;
begin
  List := TList<ITileImagePart>.Create;
  try
    for Frame in FFrames do
      List.Add(Frame as ITileImagePart);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TAnimation.AddPartLike(Image: TTileImage; RefPart: ITileImagePart);
var
  FramePart: TAnimationFrame;
begin
  FramePart := RefPart as TAnimationFrame;
  AddFrame(Image, FramePart.Duration);
end;

function TAnimation.AsTileImage: TTileImage;
begin
  Result := Self;
end;

procedure TAnimation.AddFrame(Image: TTileImage; Duration: Integer);
var
  Frame: TAnimationFrame;
begin
  Inc(FTotalDuration, Duration);
  Frame := TAnimationFrame.Create(Image, Duration);
  FFrames.Add(Frame);
end;

function TAnimation.GetFrameByTime(ACycle: Integer): TTileImage;
var
  T: Integer;
  I, NFramesLessOne: Integer;
  Frame: TAnimationFrame;
begin
  if FFrames.Count < 1 then
    raise Exception.Create('No frames in animation');
  if FTotalDuration <= 0 then
    raise Exception.Create('Total duration must be > 0');

  T := (ACycle * DEFAULT_DURATION) mod FTotalDuration;
  NFramesLessOne := FFrames.Count - 1;

  for I := 0 to NFramesLessOne - 1 do
  begin
    Frame := FFrames[I];
    Dec(T, Frame.Duration);
    if T < 0 then
      Exit(Frame.Frame);
  end;

  Result := FFrames[NFramesLessOne].Frame;
end;

function TAnimation.GetDefaultImage: TTileImage;
begin
  if FFrames.Count = 0 then
    raise Exception.Create('No frames available');
  Result := FFrames[0].Frame;
end;

procedure TAnimation.DrawFragment(Gr: TCanvas; DestX, DestY, SrcX, SrcY: Integer);
begin
  // Warning: drawing without considering animation, use default image
  GetDefaultImage.DrawFragment(Gr, DestX, DestY, SrcX, SrcY);
end;

end.