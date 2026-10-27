MODULE PNG;  (** PNG pictures for Pictures: "png = PNG.InitPicture" in PictureConverters of Oberon.Text *)

(** Pictures.Open reads .png files through InitPicture (the pictures of WebNav and of every program
  on Pictures). The picture is decoded by PNG0 and made a Picture of at most 256 colours by
  RGBPictures, transparent pixels blended over background. Store writes a Picture as a PNG file. *)

IMPORT Files, Objects, Pictures, PNG0, RGBPictures;

VAR
  background*: LONGINT;  (** the colour transparent pixels are blended over, 0RRGGBBH (white) *)

(* decode the PNG picture of R into P *)
PROCEDURE Load(VAR R: Files.Rider; P: Pictures.Picture): BOOLEAN;
VAR img: PNG0.Image; res: LONGINT;
BEGIN
  PNG0.Decode(R, img, res);
  IF (res # PNG0.ok) OR (img.width > MAX(INTEGER)) OR (img.height > MAX(INTEGER)) THEN RETURN FALSE END;
  RGBPictures.Make(P, img.width, img.height, img.pix^, background);
  RETURN TRUE
END Load;

PROCEDURE Handle*(obj: Objects.Object; VAR M: Objects.ObjMsg);
VAR start: LONGINT;
BEGIN
  WITH obj: Pictures.Picture DO
    IF M IS Objects.AttrMsg THEN
      WITH M: Objects.AttrMsg DO
        IF (M.id = Objects.get) & (M.name = "Gen") THEN M.class := Objects.String; M.s := "Pictures.NewPicture"; M.res := 0
        ELSE Pictures.Handle(obj, M)
        END
      END
    ELSIF M IS Objects.FileMsg THEN
      WITH M: Objects.FileMsg DO
        IF M.id = Objects.load THEN
          start := Files.Pos(M.R);
          IF Load(M.R, obj) THEN M.len := Files.Pos(M.R) - start ELSE M.len := 0 END
        ELSE Pictures.Handle(obj, M)
        END
      END
    ELSE Pictures.Handle(obj, M)
    END
  END
END Handle;

(** called by Pictures.Open for a .png file: the picture is loaded by Handle *)
PROCEDURE InitPicture*;
BEGIN Objects.NewObj.handle := Handle
END InitPicture;

PROCEDURE NewPicture*;
VAR P: Pictures.Picture;
BEGIN NEW(P); P.handle := Handle; Objects.NewObj := P
END NewPicture;

(** write the picture P to W as an RGB PNG picture; res as PNG0.Encode *)
PROCEDURE Store*(P: Pictures.Picture; VAR W: Files.Rider; VAR res: LONGINT);
VAR img: PNG0.Image; line: POINTER TO ARRAY OF INTEGER; x, y, i: LONGINT; r, g, b: INTEGER;
BEGIN
  img := PNG0.NewImage(P.width, P.height);
  IF img.pix = NIL THEN res := PNG0.noImage; RETURN END;
  NEW(line, P.width); y := 0;
  WHILE y < P.height DO
    Pictures.GetLine(P, line^, 0, SHORT(P.height - 1 - y), P.width); x := 0;
    WHILE x < P.width DO
      Pictures.GetColor(P, line[x], r, g, b); i := (y * P.width + x) * 4;
      img.pix[i] := CHR(r); img.pix[i + 1] := CHR(g); img.pix[i + 2] := CHR(b); img.pix[i + 3] := 0FFX;
      INC(x)
    END;
    INC(y)
  END;
  PNG0.Encode(W, img, -1, res)
END Store;

BEGIN
  background := 0FFFFFFH
END PNG.
