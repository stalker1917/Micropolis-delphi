unit TileImage;   //Обьединить в один юнит с Animation

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Fmx.Graphics,
  System.Types,System.StrUtils,
  Xml.XMLIntf, Xml.XMLDoc, Xml.XMLDom, XML_Helper;

const STD_SIZE = 16;

type
  TTileImage = class;
  TAnimation = class;
  IPart = interface
    function GetImage: TTileImage;
  end;

  // Frame class implementing IPart
  TAnimationFrame = class(TInterfacedObject, IPart)
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



  //IMultiPart = interface ['{F63B952D-9A01-4726-8183-BE9311C41B97}']
 //   function MakeEmptyCopy: IMultiPart;
//    function Parts: IEnumerable;
//   procedure AddPartLike(m: TTileImage; p: TObject);
  //  function AsTileImage: TTileImage;
 // end;



  TTileImage = class

    procedure DrawFragment(ACanvas: TCanvas; DestX, DestY, SrcX, SrcY: Integer); virtual; abstract;
    procedure DrawTo(ACanvas: TCanvas; DestX, DestY: Integer);
    function NormalForm: TTileImage; virtual;

    function MakeEmptyCopy: TAnimation; virtual; abstract;
    function Parts: TArray<IPart>; virtual; abstract;
    procedure AddPartLike(Image: TTileImage; RefPart: IPart); virtual; abstract;
    function AsTileImage: TTileImage; virtual; abstract;
  end;

  TTileImageLayer = class(TTileImage)
  public
    Below: TTileImage;
    Above: TTileImage;

    constructor Create(const ABelow, AAbove: TTileImage);
    function NormalForm: TTileImage; override;
    procedure DrawFragment(ACanvas: TCanvas; DestX, DestY, SrcX, SrcY: Integer); override;
  end;

  TTileImageSprite = class(TTileImage)
  public
    Source: TTileImage;
    OffsetX, OffsetY: Integer;

    constructor Create(ASource: TTileImage);
    function NormalForm: TTileImage; override;
    procedure DrawFragment(ACanvas: TCanvas; DestX, DestY, SrcX, SrcY: Integer); override;
  private
    function SameTransformFor(Img: TTileImage): TTileImageSprite;
  end;

  TSourceImage = class(TTileImage)
  public
    Image: TBitmap;
    BasisSize: Integer;

    constructor Create(AImage: TBitmap; ABasisSize: Integer);
    procedure DrawFragment(ACanvas: TCanvas; DestX, DestY, SrcX, SrcY: Integer); override;
  end;

  TScaledSourceImage = class(TSourceImage)
  public
    TargetSize: Integer;

    constructor Create(AImage: TBitmap; ABasisSize, ATargetSize: Integer);
    procedure DrawFragment(ACanvas: TCanvas; DestX, DestY, SrcX, SrcY: Integer); override;
  end;

  TSimpleTileImage = class(TTileImage)
  public
    SrcImage: TSourceImage;
    OffsetX, OffsetY: Integer;

    procedure DrawFragment(ACanvas: TCanvas; DestX, DestY, SrcX, SrcY: Integer); override;
  end;

  ILoaderContext = interface
    function GetDefaultImage: TSourceImage;
    function GetImage(const Name: string): TSourceImage;
    function ParseFrameSpec(const Tmp: string): TTileImage;
  end;

  TAnimation = class(TTileImage)
  private
    const
      DEFAULT_DURATION = 125;
  private
    FFrames: TObjectList<TAnimationFrame>;
    FTotalDuration: Integer;


    procedure LoadFromXML(const XMLNode: IXMLNode; const Context: ILoaderContext);
    function GetDefaultImage: TTileImage;
  public
    constructor Create;
    destructor Destroy; override;

    class function Read(InReader: IXMLNode; Ctx: ILoaderContext): TAnimation;
    class function Load(const AniFileName: string; const Context: ILoaderContext): TAnimation;

    // IMultiPart interface
    function MakeEmptyCopy: TAnimation;  override;
    function Parts: TArray<IPart>; override;
    procedure AddPartLike(Image: TTileImage; RefPart: IPart); override;
    function AsTileImage: TTileImage; override;

    procedure AddFrame(Image: TTileImage; Duration: Integer);
    function GetFrameByTime(ACycle: Integer): TTileImage;

    procedure DrawFragment(Gr: TCanvas; DestX, DestY, SrcX, SrcY: Integer); override;

    property TotalDuration: Integer read FTotalDuration;
    property Frames: TObjectList<TAnimationFrame> read FFrames;
  end;

function ReadSimpleImage(const Reader: IXMLNode; const Ctx: ILoaderContext): TSimpleTileImage;
function ReadLayeredImage(const Reader: IXMLNode; const Ctx: ILoaderContext): TTileImage;
function ReadTileImage(const Reader: IXMLNode; const Ctx: ILoaderContext): TTileImage;
function ReadTileImageM(const Reader: IXMLNode; const Ctx: ILoaderContext): TTileImage;

implementation

constructor TTileImageLayer.Create(const ABelow, AAbove: TTileImage);
begin
  Assert(Assigned(ABelow));
  Assert(Assigned(AAbove));
  inherited Create;
  below := ABelow;
  above := AAbove;
end;

function TTileImageLayer.NormalForm: TTileImage;
var
  below1, above1: TTileImage;
  rv: TAnimation;
  p: IPart;
  m: TTileImageLayer;
begin
  below1 := below.NormalForm;
  above1 := above.NormalForm;

  if above1 is TAnimation then              // Supports(above1, IMultiPart, rv)
  begin
    rv := above1.MakeEmptyCopy;
    for p in above1.Parts do
    begin
      m := TTileImageLayer.Create(below1, p.GetImage);
      rv.AddPartLike(m, p);
    end;
    Exit(rv.AsTileImage);
  end
  else if below1 is TAnimation then
  begin
    rv := below1.MakeEmptyCopy;
    for p in below1.Parts do
    begin
      m := TTileImageLayer.Create(p.GetImage, above1);
      rv.AddPartLike(m, p);
    end;
    Exit(rv.AsTileImage);
  end
  else
    Result := TTileImageLayer.Create(below1, above1);
end;

procedure TTileImageLayer.DrawFragment(ACanvas: TCanvas; destX, destY, srcX, srcY: Integer);
begin
  below.DrawFragment(ACanvas, destX, destY, srcX, srcY);
  above.DrawFragment(ACanvas, destX, destY, srcX, srcY);
end;



procedure TTileImage.DrawTo(ACanvas: TCanvas; destX, destY: Integer);
begin
  Self.DrawFragment(ACanvas, destX, destY, 0, 0);
end;

function TTileImage.NormalForm: TTileImage;
begin
  Result := Self; // Base behavior
end;

{ TTileImageSprite }

constructor TTileImageSprite.Create(ASource: TTileImage);
begin
  inherited Create;
  source := ASource;
end;

function TTileImageSprite.SameTransformFor(img: TTileImage): TTileImageSprite;
begin
  Result := TTileImageSprite.Create(img);
  Result.offsetX := Self.offsetX;
  Result.offsetY := Self.offsetY;
end;

function TTileImageSprite.NormalForm: TTileImage;
var
  source_n: TTileImage;
  rv: TAnimation;
  p: IPart;
  m: TTileImageSprite;
begin
  source_n := source.NormalForm;
  if source_n is TAnimation then
  begin
    rv := source_n.MakeEmptyCopy;
    for p in source_n.Parts do
    begin
      m := SameTransformFor(p.GetImage);
      rv.AddPartLike(m, p);
    end;
    Exit(rv.AsTileImage);
  end
  else
    Result := SameTransformFor(source_n);
end;

procedure TTileImageSprite.DrawFragment(ACanvas: TCanvas; destX, destY, srcX, srcY: Integer);
begin
  source.DrawFragment(ACanvas, destX, destY, srcX + offsetX, srcY + offsetY);
end;

{ TSourceImage }

constructor TSourceImage.Create(AImage: TBitmap; ABasisSize: Integer);
begin
  inherited Create;
  image := AImage;
  basisSize := ABasisSize;
end;

procedure TSourceImage.DrawFragment(ACanvas:TCanvas; destX, destY, srcX, srcY: Integer);
var SourceRect, DestRect: TRectF;
begin
  //SourceRect := TRectF.Create(SrcX, SrcY,
  //                           SrcX + Image.Width,
     //                        SrcY + Image.Height);
  SourceRect := TRectF.Create(SrcX, SrcY,
                             SrcX + {Image.Width}STD_SIZE,
                             SrcY + {Image.Height}STD_SIZE);

  // Set up destination rectangle
  while DestY>4095 do
    begin
      DestY:=DestY-4096;
      DestX:=DestX+STD_SIZE;
    end;

  DestRect := TRectF.Create(DestX, DestY,
                           DestX + {Image.Width}STD_SIZE,
                           DestY + {Image.Height}STD_SIZE);


 // DestRect := TRectF.Create(DestX, DestY,
    //                       DestX + Image.Width,
        //                   DestY + Image.Height);

  // Draw the bitmap fragment
  ACanvas.DrawBitmap(Image,
                   SourceRect,
                   DestRect,
                   1.0,  // Opacity
                   True); // High quality
  //ACanvas.DrawBitmap()
  // Replace with actual Delphi graphics drawing
  // E.g., image.Canvas.CopyRect(...);
end;

{ TScaledSourceImage }

constructor TScaledSourceImage.Create(AImage: TBitmap; ABasisSize, ATargetSize: Integer);
begin
  inherited Create(AImage, ABasisSize);
  targetSize := ATargetSize;
end;

procedure TScaledSourceImage.DrawFragment(ACanvas: TCanvas; destX, destY, srcX, srcY: Integer);
begin
  srcX := srcX * basisSize div STD_SIZE;
  srcY := srcY * basisSize div STD_SIZE;
  inherited DrawFragment(ACanvas,destX, destY, srcX, srcY);
  // Replace with image scaling logic
end;

{ TSimpleTileImage }

procedure TSimpleTileImage.DrawFragment(ACanvas: TCanvas; destX, destY, srcX, srcY: Integer);
begin
  srcImage.DrawFragment(ACanvas, destX, destY, srcX + offsetX, srcY + offsetY);
end;


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

class function TAnimation.Load(const AniFileName: string; const Context: ILoaderContext): TAnimation;
var
  XMLDoc: IXMLDocument;
  RootNode: IXMLNode;
  Animation: TAnimation;
begin
  Animation := nil;
  XMLDoc := TXMLDocument.Create(nil);
  XMLDoc.Options :=  XMLDoc.Options- [doAttrNull];
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

procedure TAnimation.LoadFromXML(const XMLNode: IXMLNode; const Context: ILoaderContext);
var
  //ChildNode: IXMLNode;
  DurationStr: string;
  Duration: Integer;
  FrameImage: TTileImage;
  i:Integer;
begin
  for i:=0 to XMLNode.ChildNodes.Count -1 do
  //for ChildNode in XMLNode.ChildNodes do
  begin
    if XMLNode.ChildNodes[i].NodeType <> ntElement then
      Continue;
    if SameText(XMLNode.ChildNodes[i].NodeName, 'frame') then
    begin
      if XMLNode.ChildNodes[i].HasAttribute('duration')  then
      begin

      DurationStr :=XMLNode.ChildNodes[i].Attributes['duration'];
      if DurationStr <> '' then
        Duration := StrToIntDef(DurationStr, DEFAULT_DURATION)
      else
        Duration := DEFAULT_DURATION;
      end
      else
        Duration := DEFAULT_DURATION;
      // Assume TileImage has a method to read from XML node and context
      FrameImage := ReadTileImageM(XMLNode.ChildNodes[i], Context);
      AddFrame(FrameImage, Duration);
    end
    else
    begin
      // Unrecognized element, skip or ignore
      // No direct equivalent of skipToEndElement needed here since we're iterating children
    end;
  end;
end;

class function TAnimation.Read(InReader: IXMLNode; Ctx: ILoaderContext): TAnimation;
begin
  Result := TAnimation.Create;
  try
    Result.LoadFromXML(InReader, Ctx);
  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;

function TAnimation.MakeEmptyCopy;
begin
  Result := TAnimation.Create;
end;

function TAnimation.Parts: TArray<IPart>;
var
  List: TList<IPart>;
  Frame: TAnimationFrame;
begin
  List := TList<IPart>.Create;
  try
    for Frame in FFrames do
      List.Add(Frame as IPart );
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TAnimation.AddPartLike(Image: TTileImage; RefPart: IPart);
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

{ TTileImageReader }

function ReadSimpleImage(const Reader: IXMLNode; const Ctx: ILoaderContext): TSimpleTileImage;
var
  SrcImageName, Tmp: string;
  Coords: TArray<string>;
begin
  Result := TSimpleTileImage.Create;
  try
    // Read source image
    SrcImageName := Reader.GetAttribute('src');
    if SrcImageName <> '' then
      Result.SrcImage := Ctx.GetImage('./graphics/'+SrcImageName)
    else
      Result.SrcImage := Ctx.GetDefaultImage;

    // Read coordinates
    Tmp := Reader.GetAttribute('at');
    if Tmp <> '' then
    begin
      Coords := Tmp.Split([',']);
      if Length(Coords) = 2 then
      begin
        Result.OffsetX := StrToInt(Coords[0]);
        Result.OffsetY := StrToInt(Coords[1]);
      end
      //else
       // raise EXMLException.Create('Invalid "at" syntax');
    end;

    //XMLHelper.SkipToEndElement(InReader);
  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;

function ReadLayeredImage(const Reader: IXMLNode;const  Ctx: ILoaderContext): TTileImage;
var
  ResultImg, NewImg: TTileImage;
  i:Integer;
begin
  ResultImg := nil;
  for i:=0 to Reader.ChildNodes.Count -1 do
 // while InReader.MoveToNextElement do
  begin
    if Reader.ChildNodes[i].NodeType <> ntElement then
      Continue;

    NewImg := ReadTileImage(Reader.ChildNodes[i], Ctx);
    if ResultImg = nil then
      ResultImg := NewImg
    else
      ResultImg := TTileImageLayer.Create(ResultImg, NewImg);
  end;

  //if ResultImg = nil then
   // raise EXMLException.Create('Layer must have at least one image');

  Result := ResultImg;
end;

function ReadTileImage(const Reader: IXMLNode;const Ctx: ILoaderContext): TTileImage;

var
  TagName: string;
begin
 // exit;
  TagName := Reader.LocalName;

  if TagName = 'image' then
    Result := ReadSimpleImage(Reader, Ctx)
  else if TagName = 'animation' then
    Result := TAnimation.Read(Reader, Ctx)
  else if TagName = 'layered-image' then
    Result := ReadLayeredImage(Reader, Ctx);
  //else
    //raise EXMLException.CreateFmt('Unrecognized tag: %s', [TagName]);
end;



function ReadTileImageM(const Reader: IXMLNode; const Ctx: ILoaderContext): TTileImage;
var
  Img: TTileImage;
  TagName: string;
  i:Integer;
begin
  //if Reader=nil then
   // exit;
  Img := nil;
  for i:=0 to Reader.ChildNodes.Count -1 do
 // while Reader.MoveToNextElement do
  begin
    if Reader.ChildNodes[i].NodeType <> ntElement then
      Continue;

    TagName := Reader.ChildNodes[i].LocalName;
    if MatchStr(TagName, ['image', 'animation', 'layered-image']) then
      Img := ReadTileImage(Reader.ChildNodes[i], Ctx)
    else
      //XMLHelper.SkipToEndElement(InReader);
  end;

  //if Img = nil then
  //  raise EXMLException.Create('Missing image descriptor');

  Result := Img;
end;

end. 


