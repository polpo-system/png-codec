MODULE PNGImages;  (** PNG pictures for Images: "png = PNGImages.Install" in ImageFormats of Oberon.Text *)

(** Images.Load and Images.Store read and write .png files through Install: pictures with alpha
  as BGRA8888 (alpha premultiplied, as Images keeps it), others as BGR888; stored pictures are
  8-bit RGBA PNG pictures. Decoding and encoding are PNG0's. *)

IMPORT Files, Images, PNG0;

PROCEDURE Load(img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
VAR f: Files.File; R: Files.Rider; p: PNG0.Image; res, x, y, s, d, a: LONGINT;
BEGIN
  done := FALSE; f := Files.Old(fname);
  IF f = NIL THEN RETURN END;
  Files.Set(R, f, 0); PNG0.Decode(R, p, res); Files.Close(f);
  IF (res # PNG0.ok) OR (p.width > MAX(INTEGER)) OR (p.height > MAX(INTEGER)) THEN RETURN END;
  IF p.alpha THEN Images.Create(img, SHORT(p.width), SHORT(p.height), Images.BGRA8888)
  ELSE Images.Create(img, SHORT(p.width), SHORT(p.height), Images.BGR888)
  END;
  y := 0;
  WHILE y < p.height DO  (* the top row of the PNG picture is the last row of the image *)
    s := y * p.width * 4; d := (p.height - 1 - y) * img.bpr; x := 0;
    WHILE x < p.width DO
      IF p.alpha THEN
        a := ORD(p.pix[s + 3]);
        img.mem[d] := CHR(ORD(p.pix[s + 2]) * a DIV 255); img.mem[d + 1] := CHR(ORD(p.pix[s + 1]) * a DIV 255);
        img.mem[d + 2] := CHR(ORD(p.pix[s]) * a DIV 255); img.mem[d + 3] := CHR(a); INC(d, 4)
      ELSE
        img.mem[d] := p.pix[s + 2]; img.mem[d + 1] := p.pix[s + 1]; img.mem[d + 2] := p.pix[s]; INC(d, 3)
      END;
      INC(s, 4); INC(x)
    END;
    INC(y)
  END;
  done := TRUE
END Load;

PROCEDURE Store(img: Images.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
VAR f: Files.File; W: Files.Rider; p: PNG0.Image; res, x, y, d, a, c: LONGINT; row: POINTER TO ARRAY OF CHAR;
  fmt: Images.Format; mode: Images.Mode;
BEGIN
  done := FALSE;
  p := PNG0.NewImage(img.width, img.height);
  IF p.pix = NIL THEN RETURN END;
  fmt := Images.BGRA8888; Images.InitMode(mode, Images.srcCopy);
  NEW(row, LONG(img.width) * 4); p.alpha := FALSE; y := 0;
  WHILE y < img.height DO
    Images.GetPixels(img, 0, SHORT(img.height - 1 - y), img.width, fmt, row^, mode);
    d := y * img.width * 4; x := 0;
    WHILE x < img.width DO
      a := ORD(row[4 * x + 3]);
      IF a = 255 THEN
        p.pix[d] := row[4 * x + 2]; p.pix[d + 1] := row[4 * x + 1]; p.pix[d + 2] := row[4 * x]
      ELSIF a = 0 THEN p.pix[d] := 0X; p.pix[d + 1] := 0X; p.pix[d + 2] := 0X; p.alpha := TRUE
      ELSE  (* not premultiplied in PNG *)
        c := ORD(row[4 * x + 2]) * 255 DIV a; IF c > 255 THEN c := 255 END; p.pix[d] := CHR(c);
        c := ORD(row[4 * x + 1]) * 255 DIV a; IF c > 255 THEN c := 255 END; p.pix[d + 1] := CHR(c);
        c := ORD(row[4 * x]) * 255 DIV a; IF c > 255 THEN c := 255 END; p.pix[d + 2] := CHR(c);
        p.alpha := TRUE
      END;
      p.pix[d + 3] := CHR(a); INC(d, 4); INC(x)
    END;
    INC(y)
  END;
  f := Files.New(fname); Files.Set(W, f, 0);
  PNG0.Encode(W, p, -1, res);
  IF res = PNG0.ok THEN Files.Register(f); done := TRUE END;
  Files.Close(f)
END Store;

(** called by Images for .png files *)
PROCEDURE Install*;
BEGIN Images.LoadProc := Load; Images.StoreProc := Store
END Install;

END PNGImages.
