MODULE PNGImagesTest;  (* loksh PNGImagesTest.Run: PNG pictures through Images; needs the desktop's display *)

(* with pictures of PngSuite in the current directory: basn2c08.png (RGB), basn6a08.png (RGB and
  alpha). Images.Load gives the pixels of PNG0 (alpha premultiplied); Images.Store writes them back,
  read again by PNG0 with the same colours where they are opaque. *)

IMPORT Files, Images, out, PNG0;

VAR checks, failed: LONGINT;

PROCEDURE Check(what: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  INC(checks);
  IF ~ok THEN INC(failed); out.String("FAIL "); out.String(what); out.Ln END
END Check;

PROCEDURE Decode(name: ARRAY OF CHAR): PNG0.Image;
VAR f: Files.File; R: Files.Rider; img: PNG0.Image; res: LONGINT;
BEGIN
  f := Files.Old(name); IF f = NIL THEN RETURN NIL END;
  Files.Set(R, f, 0); PNG0.Decode(R, img, res); Files.Close(f);
  IF res # PNG0.ok THEN RETURN NIL END;
  RETURN img
END Decode;

(* does img (Images) have the pixels of p (PNG0), alpha premultiplied, within 1 *)
PROCEDURE SameImage(img: Images.Image; p: PNG0.Image): BOOLEAN;
VAR x, y, s, a, k, b: LONGINT; mode: Images.Mode; fmt: Images.Format; row: ARRAY 4 OF CHAR;
BEGIN
  IF (img.width # p.width) OR (img.height # p.height) THEN RETURN FALSE END;
  fmt := Images.BGRA8888; Images.InitMode(mode, Images.srcCopy); y := 0;
  WHILE y < p.height DO
    x := 0;
    WHILE x < p.width DO
      Images.GetPixels(img, SHORT(x), SHORT(p.height - 1 - y), 1, fmt, row, mode);
      s := (y * p.width + x) * 4; a := ORD(p.pix[s + 3]);
      IF ABS(ORD(row[3]) - a) > 1 THEN RETURN FALSE END;
      k := 0;
      WHILE k < 3 DO
        b := ORD(p.pix[s + 2 - k]) * a DIV 255;  (* row: blue, green, red *)
        IF ABS(ORD(row[k]) - b) > 1 THEN RETURN FALSE END;
        INC(k)
      END;
      INC(x)
    END;
    INC(y)
  END;
  RETURN TRUE
END SameImage;

(* the opaque pixels of a and b equal, within 2 (one condition at a time: the ARMv7 compiler
  stopped at ASSERT 61 in AOPC.Index on A & (B OR C OR D) of open array elements in a loop) *)
PROCEDURE SameOpaque(a, b: PNG0.Image): BOOLEAN;
VAR i, n, k, d: LONGINT;
BEGIN
  IF (a = NIL) OR (b = NIL) OR (a.width # b.width) OR (a.height # b.height) THEN RETURN FALSE END;
  i := 0; n := a.width * a.height;
  WHILE i < n DO
    IF a.pix[4 * i + 3] = 0FFX THEN
      k := 0;
      WHILE k < 3 DO
        d := ORD(a.pix[4 * i + k]) - ORD(b.pix[4 * i + k]);
        IF ABS(d) > 2 THEN RETURN FALSE END;
        INC(k)
      END
    END;
    INC(i)
  END;
  RETURN TRUE
END SameOpaque;

PROCEDURE ImagesCase(name: ARRAY OF CHAR);
VAR img: Images.Image; done: BOOLEAN; p, q: PNG0.Image; fname: ARRAY 32 OF CHAR;
BEGIN
  p := Decode(name); NEW(img); Images.Load(img, name, done);
  Check(name, done & (p # NIL) & SameImage(img, p));
  IF done THEN
    fname := "zq_store.png"; Images.Store(img, fname, done);
    q := Decode(fname);
    Check("Images.Store", done & SameOpaque(p, q))
  END
END ImagesCase;

PROCEDURE Run*;
BEGIN
  checks := 0; failed := 0;
  ImagesCase("basn2c08.png"); ImagesCase("basn6a08.png");
  out.String("PNGImagesTest: "); out.Int(checks, 0); out.String(" checks, "); out.Int(failed, 0); out.String(" failed"); out.Ln
END Run;

END PNGImagesTest.
