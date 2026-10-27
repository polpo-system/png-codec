MODULE PNGPicturesTest;  (* loksh PNGPicturesTest.Run: PNG pictures through Pictures; needs the desktop's display *)

(* with pictures of PngSuite in the current directory: Pictures.Open gives a picture of their size
  (basn2c08.png, RGB), with the exact colours of a palette picture (basn3p08.png). *)

IMPORT Files, Pictures, out, PNG0;

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

PROCEDURE Run*;
VAR P: Pictures.Picture; p: PNG0.Image; x, y, s: LONGINT; r, g, b: INTEGER; exact: BOOLEAN;
BEGIN
  checks := 0; failed := 0;
  NEW(P); Pictures.Open(P, "basn2c08.png", TRUE);
  Check("Pictures.Open basn2c08.png", (P.width = 32) & (P.height = 32) & (P.depth = 8));
  NEW(P); Pictures.Open(P, "basn3p08.png", TRUE); p := Decode("basn3p08.png");
  exact := (P.width = 32) & (P.height = 32) & (p # NIL); y := 0;
  WHILE exact & (y < 32) DO
    x := 0;
    WHILE exact & (x < 32) DO
      Pictures.GetColor(P, Pictures.Get(P, SHORT(x), SHORT(31 - y)), r, g, b); s := (y * 32 + x) * 4;
      exact := (r = ORD(p.pix[s])) & (g = ORD(p.pix[s + 1])) & (b = ORD(p.pix[s + 2]));
      INC(x)
    END;
    INC(y)
  END;
  Check("Pictures.Open basn3p08.png: the colours of the palette", exact);
  out.String("PNGPicturesTest: "); out.Int(checks, 0); out.String(" checks, "); out.Int(failed, 0); out.String(" failed"); out.Ln
END Run;

END PNGPicturesTest.
