MODULE PNGMemoryTest;  (** loksh PNGMemoryTest.Run, PNGMemoryTest.Fixtures pngsuite.list: PNG0 in memory (PNG0.DecodeBytes, EncodeBytes, ReadInfoBytes) *)

(* After the PictureMemoryTest of voc 4.0.6. Run: a picture made here encoded into memory and decoded again,
  the same bytes as through a rider, the pixel limit and the output limit, and broken or cut data refused.
  Fixtures: each picture of the list read with the byte-array entry points and with the rider ones, the
  same results and pixels. *)

IMPORT Files, Texts, out, PNG0;

VAR checks, failed: LONGINT; phase: ARRAY 256 OF CHAR;

PROCEDURE Check(value: BOOLEAN);
BEGIN
  INC(checks);
  IF ~value THEN INC(failed); out.String("FAIL "); out.String(phase); out.String(", check "); out.Int(checks, 0); out.Ln END
END Check;

PROCEDURE Equal(VAR a, b: ARRAY OF CHAR; length: LONGINT): BOOLEAN;
VAR i: LONGINT;
BEGIN
  IF (length < 0) OR (length > LEN(a)) OR (length > LEN(b)) THEN RETURN FALSE END;
  i := 0; WHILE i < length DO IF a[i] # b[i] THEN RETURN FALSE END; INC(i) END;
  RETURN TRUE
END Equal;

PROCEDURE Fill(VAR bytes: ARRAY OF CHAR);
VAR i, seed: LONGINT;
BEGIN
  seed := 1; i := 0;
  WHILE i < LEN(bytes) DO seed := (seed * 75 + 74) MOD 65537; bytes[i] := CHR(seed MOD 256); INC(i) END
END Fill;

PROCEDURE Load(VAR name: ARRAY OF CHAR; VAR data: Files.Bytes; VAR length: LONGINT): Files.File;
VAR f: Files.File; r: Files.Rider;
BEGIN
  f := Files.Old(name); Check(f # NIL);
  IF f = NIL THEN length := 0; NEW(data, 1); RETURN NIL END;
  length := Files.Length(f);
  IF length = 0 THEN NEW(data, 1) ELSE NEW(data, length) END;
  Files.Set(r, f, 0); Files.ReadBytes(r, data^, length); Check(r.res = 0);
  RETURN f
END Load;

PROCEDURE Line(VAR R: Files.Rider; VAR s: ARRAY OF CHAR): BOOLEAN;
VAR c: CHAR; i: LONGINT;
BEGIN
  i := 0; Files.Read(R, c);
  IF R.eof THEN RETURN FALSE END;
  WHILE ~R.eof & (c # 0AX) DO IF i < LEN(s) - 1 THEN s[i] := c; INC(i) END; Files.Read(R, c) END;
  s[i] := 0X; RETURN TRUE
END Line;

PROCEDURE PNG;
VAR img, decoded, riderImage, bad: PNG0.Image; info: PNG0.Info; data, copy, encoded: Files.Bytes;
  f: Files.File; r: Files.Rider; n, m, res, i: LONGINT; saved: ARRAY 4 OF CHAR;
BEGIN
  phase := "PNG memory round trips and alpha";
  img := PNG0.NewImage(256, 192); img.alpha := TRUE; Fill(img.pix^);
  img.pix[3] := 0X; img.pix[7] := 80X; img.pix[11] := 0FFX;
  PNG0.EncodeBytes(img, 6, 524288, data, n, res); Check((res = PNG0.ok) & (n > 16384) & (data # NIL));
  PNG0.ReadInfoBytes(data^, n, info, res); Check((res = PNG0.ok) & (info.width = 256) & (info.height = 192) & (info.colorType = 6));
  PNG0.DecodeBytes(data^, n, 256 * 192, decoded, res); Check((res = PNG0.ok) & (decoded # NIL) & decoded.alpha);
  Check(Equal(img.pix^, decoded.pix^, 256 * 192 * 4));
  f := Files.FromBytes(data^, n); Files.Set(r, f, 0); PNG0.Decode(r, riderImage, res);
  Check((res = PNG0.ok) & Equal(decoded.pix^, riderImage.pix^, 256 * 192 * 4));
  f := Files.NewMemory(524288); Files.Set(r, f, 0); PNG0.Encode(r, img, 6, res); copy := Files.MemoryData(f, m);
  Check((res = PNG0.ok) & (m = n) & Equal(data^, copy^, n));

  phase := "PNG limits and malformed buffers";
  PNG0.DecodeBytes(data^, n, 256 * 192 - 1, decoded, res); Check((res = PNG0.tooLarge) & (decoded = NIL));
  PNG0.DecodeBytes(data^, n, 0, decoded, res); Check((res = PNG0.tooLarge) & (decoded = NIL));
  PNG0.DecodeBytes(data^, n, PNG0.MaxPixels + 1, decoded, res); Check((res = PNG0.tooLarge) & (decoded = NIL));
  PNG0.DecodeBytes(data^, -1, PNG0.MaxPixels, decoded, res); Check((res = PNG0.badFormat) & (decoded = NIL));
  PNG0.DecodeBytes(data^, LEN(data^) + 1, PNG0.MaxPixels, decoded, res); Check((res = PNG0.badFormat) & (decoded = NIL));
  PNG0.DecodeBytes(data^, 5, PNG0.MaxPixels, decoded, res); Check((res # PNG0.ok) & (decoded = NIL));
  PNG0.EncodeBytes(img, 6, n - 1, encoded, m, res); Check((res = PNG0.tooLarge) & (encoded = NIL) & (m = 0));
  PNG0.EncodeBytes(img, 6, n, encoded, m, res); Check((res = PNG0.ok) & (m = n) & Equal(data^, encoded^, n));
  PNG0.EncodeBytes(img, 6, 0, encoded, m, res); Check((res = PNG0.tooLarge) & (encoded = NIL) & (m = 0));
  data[n - 1] := CHR((ORD(data[n - 1]) + 1) MOD 256);
  PNG0.DecodeBytes(data^, n, PNG0.MaxPixels, decoded, res); Check((res = PNG0.badCRC) & (decoded = NIL));
  FOR i := 0 TO 3 DO saved[i] := data[33 + i] END;
  data[33] := 7FX; data[34] := 0FFX; data[35] := 0FFX; data[36] := 0E0X;
  PNG0.DecodeBytes(data^, n, PNG0.MaxPixels, decoded, res); Check((res = PNG0.badFormat) & (decoded = NIL));
  FOR i := 0 TO 3 DO data[33 + i] := saved[i] END;
  NEW(bad); bad.width := 2; bad.height := 2; NEW(bad.pix, 3);
  PNG0.EncodeBytes(bad, 6, 4096, encoded, m, res); Check((res = PNG0.noImage) & (encoded = NIL) & (m = 0));
  bad.width := MAX(LONGINT); bad.height := MAX(LONGINT);
  PNG0.EncodeBytes(bad, 6, 4096, encoded, m, res); Check((res = PNG0.tooLarge) & (encoded = NIL) & (m = 0))
END PNG;

PROCEDURE Fixture(VAR name: ARRAY OF CHAR);
VAR f: Files.File; r: Files.Rider; data: Files.Bytes; length, a, b: LONGINT; p, pc: PNG0.Image; pi, pic: PNG0.Info;
BEGIN
  COPY(name, phase); f := Load(name, data, length);
  IF f = NIL THEN RETURN END;
  Files.Set(r, f, 0); PNG0.ReadInfo(r, pi, a); PNG0.ReadInfoBytes(data^, length, pic, b); Check(a = b);
  IF a = PNG0.ok THEN
    Check((pi.width = pic.width) & (pi.height = pic.height) & (pi.depth = pic.depth) &
      (pi.colorType = pic.colorType) & (pi.interlaced = pic.interlaced))
  END;
  Files.Set(r, f, 0); PNG0.Decode(r, p, a); PNG0.DecodeBytes(data^, length, PNG0.MaxPixels, pc, b); Check(a = b);
  IF a = PNG0.ok THEN
    Check((pc # NIL) & (p.width = pc.width) & (p.height = pc.height) & (p.alpha = pc.alpha));
    Check((pc # NIL) & Equal(p.pix^, pc.pix^, p.width * p.height * 4))
  ELSE Check(pc = NIL)
  END;
  Files.Close(f)
END Fixture;

(** PNGMemoryTest.Run: memory round trips and limits *)
PROCEDURE Run*;
BEGIN
  checks := 0; failed := 0; PNG;
  out.String("PNGMemoryTest: "); out.Int(checks, 0); out.String(" checks, "); out.Int(failed, 0); out.String(" failed"); out.Ln
END Run;

(** PNGMemoryTest.Fixtures list: the byte-array entry points against the rider ones on every picture of list *)
PROCEDURE Fixtures*;
VAR A: Texts.Reader; f: Files.File; r: Files.Rider; list: ARRAY 256 OF CHAR; line, name: ARRAY 256 OF CHAR; i: LONGINT;
BEGIN
  checks := 0; failed := 0; Texts.OpenArgs(A);
  IF ~Texts.Arg(A, list) THEN out.String("usage: PNGMemoryTest.Fixtures pngsuite.list"); out.Ln; RETURN END;
  f := Files.Old(list);
  IF f = NIL THEN out.String("FAIL no "); out.String(list); out.Ln; RETURN END;
  Files.Set(r, f, 0);
  WHILE Line(r, line) DO
    i := 0; WHILE (line[i] > " ") & (i < LEN(name) - 1) DO name[i] := line[i]; INC(i) END;
    name[i] := 0X;
    IF (i > 0) & (name[0] # "#") THEN Fixture(name) END
  END;
  out.String("PNGMemoryTest fixtures: "); out.Int(checks, 0); out.String(" checks, "); out.Int(failed, 0); out.String(" failed"); out.Ln
END Fixtures;

END PNGMemoryTest.
