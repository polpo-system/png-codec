MODULE RGBPictures;  (** pictures of 8-bit red, green, blue and alpha as Pictures (at most 8 bits a pixel) *)

(** Make(P, w, h, pix, bg) fills the picture P with the pixels pix (the rows from the top, 4 bytes
  a pixel: red, green, blue, alpha), each pixel blended over the colour bg (0RRGGBBH) by its alpha.
  Pictures have a palette of at most 256 colours: a picture with no more colours gets exactly its
  own, a grey one 256 greys, any other the 216 colours of a 6 x 6 x 6 cube with Floyd-Steinberg
  dithering. Used by PNG for the pictures of PNG0. *)

IMPORT Pictures;

CONST Buckets = 1024;

VAR
  white*: LONGINT;  (** 0FFFFFFH, the usual background *)
  table: ARRAY 256 OF LONGINT; n: LONGINT;  (* the colours found, at most 256 *)
  hash: ARRAY Buckets OF LONGINT;  (* index + 1 in table, 0 free *)

(* the index of colour c in table, added if new; -1 if there are already 256 *)
PROCEDURE Index(c: LONGINT): LONGINT;
VAR h: LONGINT;
BEGIN
  h := (c * 7 + c DIV 4096) MOD Buckets;
  WHILE (hash[h] # 0) & (table[hash[h] - 1] # c) DO h := (h + 1) MOD Buckets END;
  IF hash[h] # 0 THEN RETURN hash[h] - 1 END;
  IF n = 256 THEN RETURN -1 END;
  table[n] := c; INC(n); hash[h] := n;
  RETURN n - 1
END Index;

PROCEDURE Blend(v, a, back: LONGINT): LONGINT;
BEGIN RETURN (v * a + back * (255 - a) + 127) DIV 255
END Blend;

(* the colour of pixel i of pix over bg, as 0RRGGBBH *)
PROCEDURE Pixel(VAR pix: ARRAY OF CHAR; i, bg: LONGINT): LONGINT;
VAR a, r, g, b: LONGINT;
BEGIN
  a := ORD(pix[4 * i + 3]); r := ORD(pix[4 * i]); g := ORD(pix[4 * i + 1]); b := ORD(pix[4 * i + 2]);
  IF a # 255 THEN
    r := Blend(r, a, bg DIV 10000H MOD 100H); g := Blend(g, a, bg DIV 100H MOD 100H); b := Blend(b, a, bg MOD 100H)
  END;
  RETURN (r * 100H + g) * 100H + b
END Pixel;

PROCEDURE Clamp(x: LONGINT): LONGINT;
BEGIN IF x < 0 THEN RETURN 0 ELSIF x > 255 THEN RETURN 255 ELSE RETURN x END
END Clamp;

(** fill P (created here, w by h, 8 bits) with the pixels pix over the background bg *)
PROCEDURE Make*(P: Pictures.Picture; w, h: LONGINT; VAR pix: ARRAY OF CHAR; bg: LONGINT);
VAR x, y, i, c, k, r, g, b, er, eg, eb, nr, ir, ig, ib: LONGINT; exact, grey: BOOLEAN;
  line: POINTER TO ARRAY OF INTEGER;
  cur, next: POINTER TO ARRAY OF LONGINT;  (* the errors of Floyd-Steinberg, 3 a pixel, one pixel more at each end *)
BEGIN
  Pictures.Create(P, SHORT(w), SHORT(h), 8);
  NEW(line, w);
  (* the colours: exact if at most 256; grey? *)
  n := 0; i := 0; WHILE i < Buckets DO hash[i] := 0; INC(i) END;
  exact := TRUE; grey := TRUE; i := 0;
  WHILE i < w * h DO
    c := Pixel(pix, i, bg);
    IF grey & ((c DIV 10000H # c MOD 100H) OR (c DIV 100H MOD 100H # c MOD 100H)) THEN grey := FALSE END;
    IF exact & (Index(c) < 0) THEN exact := FALSE END;
    IF ~exact & ~grey THEN i := w * h ELSE INC(i) END
  END;
  IF exact THEN
    k := 0; WHILE k < n DO Pictures.SetColor(P, SHORT(k), SHORT(table[k] DIV 10000H), SHORT(table[k] DIV 100H MOD 100H), SHORT(table[k] MOD 100H)); INC(k) END;
    y := 0;
    WHILE y < h DO
      x := 0; WHILE x < w DO line[x] := SHORT(Index(Pixel(pix, y * w + x, bg))); INC(x) END;
      Pictures.PutLine(P, line^, 0, SHORT(h - 1 - y), SHORT(w)); INC(y)
    END
  ELSIF grey THEN
    k := 0; WHILE k < 256 DO Pictures.SetColor(P, SHORT(k), SHORT(k), SHORT(k), SHORT(k)); INC(k) END;
    y := 0;
    WHILE y < h DO
      x := 0; WHILE x < w DO line[x] := SHORT(Pixel(pix, y * w + x, bg) MOD 100H); INC(x) END;
      Pictures.PutLine(P, line^, 0, SHORT(h - 1 - y), SHORT(w)); INC(y)
    END
  ELSE
    k := 0;
    WHILE k < 216 DO Pictures.SetColor(P, SHORT(k), SHORT(k DIV 36 * 51), SHORT(k DIV 6 MOD 6 * 51), SHORT(k MOD 6 * 51)); INC(k) END;
    NEW(cur, 3 * (w + 2)); NEW(next, 3 * (w + 2));
    i := 0; WHILE i < 3 * (w + 2) DO cur[i] := 0; next[i] := 0; INC(i) END;
    y := 0;
    WHILE y < h DO
      x := 0;
      WHILE x < w DO
        c := Pixel(pix, y * w + x, bg);
        r := Clamp(c DIV 10000H + cur[3 * (x + 1)] DIV 16);
        g := Clamp(c DIV 100H MOD 100H + cur[3 * (x + 1) + 1] DIV 16);
        b := Clamp(c MOD 100H + cur[3 * (x + 1) + 2] DIV 16);
        ir := (r + 25) DIV 51; ig := (g + 25) DIV 51; ib := (b + 25) DIV 51;
        line[x] := SHORT(ir * 36 + ig * 6 + ib);
        er := r - ir * 51; eg := g - ig * 51; eb := b - ib * 51;
        (* 7/16 to the right, 3/16 below left, 5/16 below, 1/16 below right (errors kept times 16) *)
        INC(cur[3 * (x + 2)], er * 7); INC(cur[3 * (x + 2) + 1], eg * 7); INC(cur[3 * (x + 2) + 2], eb * 7);
        INC(next[3 * x], er * 3); INC(next[3 * x + 1], eg * 3); INC(next[3 * x + 2], eb * 3);
        INC(next[3 * (x + 1)], er * 5); INC(next[3 * (x + 1) + 1], eg * 5); INC(next[3 * (x + 1) + 2], eb * 5);
        INC(next[3 * (x + 2)], er); INC(next[3 * (x + 2) + 1], eg); INC(next[3 * (x + 2) + 2], eb);
        INC(x)
      END;
      Pictures.PutLine(P, line^, 0, SHORT(h - 1 - y), SHORT(w));
      nr := 0; WHILE nr < 3 * (w + 2) DO cur[nr] := next[nr]; next[nr] := 0; INC(nr) END;
      INC(y)
    END
  END
END Make;

BEGIN
  white := 0FFFFFFH
END RGBPictures.
