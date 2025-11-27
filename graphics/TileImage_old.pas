unit TileImage;   //Обьединить в один юнит с Animation

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Fmx.Graphics,
  Xml.XMLIntf, Xml.XMLDoc, Xml.XMLDom;

const STD_SIZE = 16;

type
  TTileImage = class;

  IMultiPart = interface ['{F63B952D-9A01-4726-8183-BE9311C41B97}']
    function MakeEmptyCopy: IMultiPart;
    function Parts: IEnumerable;
    procedure AddPartLike(m: TTileImage; p: TObject);
    function AsTileImage: TTileImage;
  end;

  IPart = interface
    function GetImage: TTileImage;
  end;

  TTileImage = class

    procedure DrawFragment(ACanvas: TCanvas; DestX, DestY, SrcX, SrcY: Integer); virtual; abstract;
    procedure DrawTo(ACanvas: TCanvas; DestX, DestY: Integer);
    function NormalForm: TTileImage; virtual;
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

function ReadSimpleImage(Reader: IXMLNode; Ctx: ILoaderContext): TSimpleTileImage;
function ReadLayeredImage(Reader: IXMLNode; Ctx: ILoaderContext): TTileImage;
function ReadTileImage(Reader: IXMLNode; Ctx: ILoaderContext): TTileImage;
function ReadTileImageM(Reader: IXMLNode; Ctx: ILoaderContext): TTileImage;

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
  rv: IMultiPart;
  p: IPart;
  m: TTileImageLayer;
begin
  below1 := below.NormalForm;
  above1 := above.NormalForm;

  if Supports(above1, IMultiPart, rv) then
  begin
    rv := IMultiPart(above1).MakeEmptyCopy;
    for p in IMultiPart(above1).Parts do
    begin
      m := TTileImageLayer.Create(below1, p.GetImage);
      rv.AddPartLike(m, p);
    end;
    Exit(rv.AsTileImage);
  end
  else if Supports(below1, IMultiPart, rv) then
  begin
    rv := IMultiPart(below1).MakeEmptyCopy;
    for p in IMultiPart(below1).Parts do
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

end.

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
  rv: IMultiPart;
  p: IPart;
  m: TTileImageSprite;
begin
  source_n := source.NormalForm;
  if Supports(source_n, IMultiPart, rv) then
  begin
    rv := IMultiPart(source_n).MakeEmptyCopy;
    for p in IMultiPart(source_n).Parts do
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

constructor TSourceImage.Create(AImage: TBufferedImage; ABasisSize: Integer);
begin
  inherited Create;
  image := AImage;
  basisSize := ABasisSize;
end;

procedure TSourceImage.DrawFragment(ACanvas:TCanvas; destX, destY, srcX, srcY: Integer);
begin
  ACanvas.CopyRect(
  // Replace with actual Delphi graphics drawing
  // E.g., image.Canvas.CopyRect(...);
end;

{ TScaledSourceImage }

constructor TScaledSourceImage.Create(AImage: TBufferedImage; ABasisSize, ATargetSize: Integer);
begin
  inherited Create(AImage, ABasisSize);
  targetSize := ATargetSize;
end;

procedure TScaledSourceImage.DrawFragment(ACanvas: TCanvas; destX, destY, srcX, srcY: Integer);
begin
  srcX := srcX * basisSize div TTileImage.STD_SIZE;
  srcY := srcY * basisSize div TTileImage.STD_SIZE;

  // Replace with image scaling logic
end;

{ TSimpleTileImage }

procedure TSimpleTileImage.DrawFragment(ACanvas: TCanvas; destX, destY, srcX, srcY: Integer);
begin
  srcImage.DrawFragment(ACanvas, destX, destY, srcX + offsetX, srcY + offsetY);
end;

end. 


