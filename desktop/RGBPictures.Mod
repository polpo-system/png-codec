MODULE RGBPictures;  (** pictures of 8-bit red, green, blue and alpha as Pictures (at most 8 bits a pixel) *)

(** Make(P, w, h, pix, bg) fills the picture P with the pixels pix (the rows from the top, 4 bytes
  a pixel: red, green, blue, alpha), each pixel blended over the colour bg (0RRGGBBH) by its alpha.
  Pictures are shown with the 256 colours of the palette of Display (the palette of a picture is
  not used when it is drawn, as with the GIF and JPEG pictures), so each pixel becomes the
  nearest colour of that palette: for a picture of at most 256 colours directly, for others with
  Floyd-Steinberg dithering. Used by PNG for the pictures of PNG0. *)

IMPORT Display, Pictures;

CONST Buckets = 1024; CacheSize = 32768;  (* 5 bits a component *)

VAR
  white*: LONGINT;  (** 0FFFFFFH, the usual background *)
  table: ARRAY 256 OF LONGINT; n: LONGINT;  (* the colours of the picture, while there are at most 256 *)
  hash: ARRAY Buckets OF LONGINT;  (* index + 1 in table, 0 free *)
  pr, pg, pb: ARRAY 256 OF LONGINT;  (* the palette of Display *)
  cache: ARRAY CacheSize OF INTEGER;  (* nearest index + 1, 0 not known *)

(* is colour c among the first 256 colours found; FALSE when there would be more *)
PROCEDURE Add(c: LONGINT): BOOLEAN;
VAR h: LONGINT;
BEGIN
  h := (c * 7 + c DIV 4096) MOD Buckets;
  WHILE (hash[h] # 0) & (table[hash[h] - 1] # c) DO h := (h + 1) MOD Buckets END;
  IF hash[h] # 0 THEN RETURN TRUE END;
  IF n = 256 THEN RETURN FALSE END;
  table[n] := c; INC(n); hash[h] := n;
  RETURN TRUE
END Add;

(* the index of the colour of the palette of Display nearest to r, g, b *)
PROCEDURE Nearest(r, g, b: LONGINT): INTEGER;
VAR key, i, d, best, bestD, dr, dg, db: LONGINT;
BEGIN
  key := (r DIV 8 * 32 + g DIV 8) * 32 + b DIV 8;
  IF cache[key] # 0 THEN RETURN cache[key] - 1 END;  (* INTEGER: SHORT would make it a SHORTINT *)
  best := 0; bestD := MAX(LONGINT); i := 0;
  WHILE i < 256 DO
    dr := r - pr[i]; dg := g - pg[i]; db := b - pb[i];
    d := 3 * dr * dr + 4 * dg * dg + 2 * db * db;  (* the eye weighs green most *)
    IF d < bestD THEN bestD := d; best := i END;
    INC(i)
  END;
  cache[key] := SHORT(best + 1);
  RETURN SHORT(best)
END Nearest;

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
VAR x, y, i, c, r, g, b, k, er, eg, eb: LONGINT; few: BOOLEAN; ri, gi, bi: INTEGER;
  line: POINTER TO ARRAY OF INTEGER;
  cur, next: POINTER TO ARRAY OF LONGINT;  (* the errors of Floyd-Steinberg times 16, 3 a pixel, one pixel more at each end *)
BEGIN
  Pictures.Create(P, SHORT(w), SHORT(h), 8);
  i := 0;
  WHILE i < 256 DO Display.GetColor(SHORT(i), ri, gi, bi); pr[i] := ri; pg[i] := gi; pb[i] := bi; INC(i) END;
  i := 0; WHILE i < CacheSize DO cache[i] := 0; INC(i) END;
  NEW(line, w);
  n := 0; i := 0; WHILE i < Buckets DO hash[i] := 0; INC(i) END;
  few := TRUE; i := 0;
  WHILE few & (i < w * h) DO few := Add(Pixel(pix, i, bg)); INC(i) END;
  IF few THEN  (* the nearest colour of each, no dithering *)
    y := 0;
    WHILE y < h DO
      x := 0;
      WHILE x < w DO
        c := Pixel(pix, y * w + x, bg); line[x] := Nearest(c DIV 10000H, c DIV 100H MOD 100H, c MOD 100H); INC(x)
      END;
      Pictures.PutLine(P, line^, 0, SHORT(h - 1 - y), SHORT(w)); INC(y)
    END
  ELSE
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
        k := Nearest(r, g, b); line[x] := SHORT(k);
        er := r - pr[k]; eg := g - pg[k]; eb := b - pb[k];
        (* 7/16 to the right, 3/16 below left, 5/16 below, 1/16 below right *)
        INC(cur[3 * (x + 2)], er * 7); INC(cur[3 * (x + 2) + 1], eg * 7); INC(cur[3 * (x + 2) + 2], eb * 7);
        INC(next[3 * x], er * 3); INC(next[3 * x + 1], eg * 3); INC(next[3 * x + 2], eb * 3);
        INC(next[3 * (x + 1)], er * 5); INC(next[3 * (x + 1) + 1], eg * 5); INC(next[3 * (x + 1) + 2], eb * 5);
        INC(next[3 * (x + 2)], er); INC(next[3 * (x + 2) + 1], eg); INC(next[3 * (x + 2) + 2], eb);
        INC(x)
      END;
      Pictures.PutLine(P, line^, 0, SHORT(h - 1 - y), SHORT(w));
      i := 0; WHILE i < 3 * (w + 2) DO cur[i] := next[i]; next[i] := 0; INC(i) END;
      INC(y)
    END
  END
END Make;

BEGIN
  white := 0FFFFFFH
END RGBPictures.
