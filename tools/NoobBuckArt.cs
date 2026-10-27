using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

// Renders the game's classic noob (same parts, sizes, colors, head mesh and face as
// src/server/Noob.luau) and draws Noob Buck bills and pack pictures with it.
public static class NoobBuckArt
{
    struct V3 { public double X, Y, Z; public V3(double x, double y, double z) { X = x; Y = y; Z = z; }
        public static V3 operator +(V3 a, V3 b) { return new V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z); }
        public static V3 operator -(V3 a, V3 b) { return new V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z); }
        public static V3 operator *(V3 a, double s) { return new V3(a.X * s, a.Y * s, a.Z * s); }
        public double Dot(V3 b) { return X * b.X + Y * b.Y + Z * b.Z; }
        public V3 Cross(V3 b) { return new V3(Y * b.Z - Z * b.Y, Z * b.X - X * b.Z, X * b.Y - Y * b.X); }
        public V3 Unit() { double m = Math.Sqrt(Dot(this)); return new V3(X / m, Y / m, Z / m); } }

    class Tri { public V3 A, B, C, NA, NB, NC; public Color Col; public int Id; public bool Face; }

    static List<Tri> tris = new List<Tri>();
    static double headMinX, headMaxX, headMinY, headMaxY;

    static void Box(V3 c, V3 s, Color col, int id)
    {
        double hx = s.X / 2, hy = s.Y / 2, hz = s.Z / 2;
        V3[] n = { new V3(1,0,0), new V3(-1,0,0), new V3(0,1,0), new V3(0,-1,0), new V3(0,0,1), new V3(0,0,-1) };
        foreach (var nn in n)
        {
            // two axes across the face
            V3 u = Math.Abs(nn.X) > 0.5 ? new V3(0, 1, 0) : new V3(1, 0, 0);
            V3 v = nn.Cross(u);
            V3 center = c + new V3(nn.X * hx, nn.Y * hy, nn.Z * hz);
            double su = Math.Abs(u.X) * hx + Math.Abs(u.Y) * hy + Math.Abs(u.Z) * hz;
            double sv = Math.Abs(v.X) * hx + Math.Abs(v.Y) * hy + Math.Abs(v.Z) * hz;
            V3 p1 = center + u * su + v * sv, p2 = center - u * su + v * sv, p3 = center - u * su - v * sv, p4 = center + u * su - v * sv;
            tris.Add(new Tri { A = p1, B = p2, C = p3, NA = nn, NB = nn, NC = nn, Col = col, Id = id });
            tris.Add(new Tri { A = p1, B = p3, C = p4, NA = nn, NB = nn, NC = nn, Col = col, Id = id });
        }
    }

    static void HeadMesh(string path, V3 center, double scale, Color col, int id)
    {
        byte[] data = File.ReadAllBytes(path);
        int start = Array.IndexOf(data, (byte)'\n') + 1;
        int headerSize = BitConverter.ToUInt16(data, start);
        int vertexSize = data[start + 2];
        int faceSize = data[start + 3];
        int nv = BitConverter.ToInt32(data, start + 4);
        int nf = BitConverter.ToInt32(data, start + 8);
        int p = start + headerSize;
        var pos = new V3[nv]; var nor = new V3[nv];
        double minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9, minZ = 1e9, maxZ = -1e9;
        for (int i = 0; i < nv; i++)
        {
            int o = p + i * vertexSize;
            pos[i] = new V3(BitConverter.ToSingle(data, o), BitConverter.ToSingle(data, o + 4), BitConverter.ToSingle(data, o + 8));
            nor[i] = new V3(BitConverter.ToSingle(data, o + 12), BitConverter.ToSingle(data, o + 16), BitConverter.ToSingle(data, o + 20));
            minX = Math.Min(minX, pos[i].X); maxX = Math.Max(maxX, pos[i].X);
            minY = Math.Min(minY, pos[i].Y); maxY = Math.Max(maxY, pos[i].Y);
            minZ = Math.Min(minZ, pos[i].Z); maxZ = Math.Max(maxZ, pos[i].Z);
        }
        Console.WriteLine("head mesh bounds: x {0:F2}..{1:F2} y {2:F2}..{3:F2} z {4:F2}..{5:F2}", minX, maxX, minY, maxY, minZ, maxZ);
        // Fit the mesh so it's `scale` studs across (like the head in the game)
        double fit = scale / (maxX - minX);
        V3 mid = new V3((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2);
        for (int i = 0; i < nv; i++) pos[i] = center + (pos[i] - mid) * fit;
        headMinX = center.X - (maxX - minX) * fit / 2; headMaxX = center.X + (maxX - minX) * fit / 2;
        headMinY = center.Y - (maxY - minY) * fit / 2; headMaxY = center.Y + (maxY - minY) * fit / 2;
        int fo = p + nv * vertexSize;
        for (int i = 0; i < nf; i++)
        {
            int o = fo + i * faceSize;
            int a = BitConverter.ToInt32(data, o), b = BitConverter.ToInt32(data, o + 4), c = BitConverter.ToInt32(data, o + 8);
            tris.Add(new Tri { A = pos[a], B = pos[b], C = pos[c], NA = nor[a], NB = nor[b], NC = nor[c], Col = col, Id = id, Face = true });
        }
    }

    // Renders the noob to a transparent bitmap. `look` = point looked at, `from` = camera.
    public static Bitmap RenderNoob(string meshPath, string facePath, int size, double[] from, double[] look, double fov)
    {
        tris.Clear();
        Color yellow = Color.FromArgb(245, 205, 48), blue = Color.FromArgb(13, 105, 172), green = Color.FromArgb(164, 189, 71);
        Box(new V3(0, 0, 0), new V3(2, 2, 1), blue, 1);
        Box(new V3(-1.5, 0, 0), new V3(1, 2, 1), yellow, 2);
        Box(new V3(1.5, 0, 0), new V3(1, 2, 1), yellow, 3);
        Box(new V3(-0.5, -2, 0), new V3(1, 2, 1), green, 4);
        Box(new V3(0.5, -2, 0), new V3(1, 2, 1), green, 5);
        HeadMesh(meshPath, new V3(0, 1.5, 0), 1.25, yellow, 6);
        Bitmap face = new Bitmap(facePath);

        int ss = 3, W = size * ss;
        double[] depth = new double[W * W]; int[] ids = new int[W * W]; Color[] cols = new Color[W * W];
        for (int i = 0; i < depth.Length; i++) depth[i] = double.MaxValue;
        V3 eye = new V3(from[0], from[1], from[2]), at = new V3(look[0], look[1], look[2]);
        V3 fwd = (at - eye).Unit(), right = fwd.Cross(new V3(0, 1, 0)).Unit(), up = right.Cross(fwd);
        double f = 1 / Math.Tan(fov * Math.PI / 360);
        // A soft key light from the camera's upper left, plus a little fill
        V3 light = (fwd * -1 + up * 0.9 - right * 0.6).Unit();
        Func<V3, double[]> project = q => {
            V3 d = q - eye; double z = d.Dot(fwd);
            return new double[] { (d.Dot(right) * f / z * 0.5 + 0.5) * W, (0.5 - d.Dot(up) * f / z * 0.5) * W, z };
        };
        foreach (var t in tris)
        {
            double[] a = project(t.A), b = project(t.B), c = project(t.C);
            double area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
            if (Math.Abs(area) < 1e-9) continue;
            int x0 = Math.Max(0, (int)Math.Floor(Math.Min(a[0], Math.Min(b[0], c[0]))));
            int x1 = Math.Min(W - 1, (int)Math.Ceiling(Math.Max(a[0], Math.Max(b[0], c[0]))));
            int y0 = Math.Max(0, (int)Math.Floor(Math.Min(a[1], Math.Min(b[1], c[1]))));
            int y1 = Math.Min(W - 1, (int)Math.Ceiling(Math.Max(a[1], Math.Max(b[1], c[1]))));
            for (int y = y0; y <= y1; y++)
                for (int x = x0; x <= x1; x++)
                {
                    double px = x + 0.5, py = y + 0.5;
                    double w0 = ((b[0] - px) * (c[1] - py) - (b[1] - py) * (c[0] - px)) / area;
                    double w1 = ((c[0] - px) * (a[1] - py) - (c[1] - py) * (a[0] - px)) / area;
                    double w2 = 1 - w0 - w1;
                    if (w0 < 0 || w1 < 0 || w2 < 0) continue;
                    double z = w0 * a[2] + w1 * b[2] + w2 * c[2];
                    int i = y * W + x;
                    if (z >= depth[i]) continue;
                    V3 n = (t.NA * w0 + t.NB * w1 + t.NC * w2).Unit();
                    if (n.Dot(fwd) > 0 && !t.Face) n = n * -1;
                    double shade = 0.62 + 0.5 * Math.Max(0, n.Dot(light));
                    Color baseCol = t.Col;
                    if (t.Face && n.Z < -0.2)
                    {
                        // The classic face decal on the front of the head (Roblox's Front is -Z)
                        V3 q = t.A * w0 + t.B * w1 + t.C * w2;
                        double u = (headMaxX - q.X) / (headMaxX - headMinX);
                        double v = (headMaxY - q.Y) / (headMaxY - headMinY);
                        int fx = (int)(u * (face.Width - 1)), fy = (int)(v * (face.Height - 1));
                        if (fx >= 0 && fy >= 0 && fx < face.Width && fy < face.Height)
                        {
                            Color fc = face.GetPixel(fx, fy);
                            double al = fc.A / 255.0;
                            baseCol = Color.FromArgb((int)(baseCol.R * (1 - al) + fc.R * al), (int)(baseCol.G * (1 - al) + fc.G * al), (int)(baseCol.B * (1 - al) + fc.B * al));
                        }
                    }
                    depth[i] = z; ids[i] = t.Id;
                    cols[i] = Color.FromArgb(Clamp(baseCol.R * shade), Clamp(baseCol.G * shade), Clamp(baseCol.B * shade));
                }
        }
        // Dark cartoon outlines where one body part meets another or the background
        int line = 3 * ss;
        Color ink = Color.FromArgb(25, 25, 35);
        Color[] outCols = (Color[])cols.Clone(); bool[] filled = new bool[W * W];
        for (int y = 0; y < W; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x; int id = ids[i];
                bool edge = false, any = id != 0;
                for (int dy = -line; dy <= line && !edge; dy++)
                    for (int dx = -line; dx <= line; dx++)
                    {
                        if (dx * dx + dy * dy > line * line) continue;
                        int xx = x + dx, yy = y + dy;
                        int other = (xx < 0 || yy < 0 || xx >= W || yy >= W) ? 0 : ids[yy * W + xx];
                        if (other != 0) any = true;
                        // Only the nearer part draws the line between two parts
                        if (other != id && (id == 0 || other == 0 || depth[i] <= depth[yy * W + xx] + 1e-9)) { edge = true; break; }
                    }
                if (edge && any) { outCols[i] = ink; filled[i] = true; }
                else if (id != 0) filled[i] = true;
            }
        Bitmap bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                double r = 0, g = 0, b = 0, a = 0;
                for (int sy = 0; sy < ss; sy++)
                    for (int sx = 0; sx < ss; sx++)
                    {
                        int i = (y * ss + sy) * W + x * ss + sx;
                        if (!filled[i]) continue;
                        r += outCols[i].R; g += outCols[i].G; b += outCols[i].B; a += 1;
                    }
                if (a > 0) bmp.SetPixel(x, y, Color.FromArgb((int)(255 * a / (ss * ss)), (int)(r / a), (int)(g / a), (int)(b / a)));
            }
        return bmp;
    }

    static int Clamp(double v) { return Math.Max(0, Math.Min(255, (int)v)); }

    static GraphicsPath Rounded(RectangleF r, float rad)
    {
        var p = new GraphicsPath();
        p.AddArc(r.X, r.Y, rad * 2, rad * 2, 180, 90);
        p.AddArc(r.Right - rad * 2, r.Y, rad * 2, rad * 2, 270, 90);
        p.AddArc(r.Right - rad * 2, r.Bottom - rad * 2, rad * 2, rad * 2, 0, 90);
        p.AddArc(r.X, r.Bottom - rad * 2, rad * 2, rad * 2, 90, 90);
        p.CloseFigure();
        return p;
    }

    static readonly Color BillGreen = Color.FromArgb(70, 160, 80), BillLight = Color.FromArgb(190, 235, 190), BillDark = Color.FromArgb(25, 85, 40);

    // One Noob Buck bill, `w` wide and w/2 tall, with its top-left corner at 0,0
    static void DrawBill(Graphics g, float w, Bitmap noob)
    {
        float h = w / 2, line = w / 70;
        var outer = new RectangleF(0, 0, w, h);
        using (var path = Rounded(outer, h * 0.12f))
        {
            using (var fill = new LinearGradientBrush(outer, Color.FromArgb(95, 185, 100), Color.FromArgb(55, 140, 70), 60f)) g.FillPath(fill, path);
            using (var pen = new Pen(BillDark, line * 1.6f)) g.DrawPath(pen, path);
        }
        var inner = new RectangleF(w * 0.05f, h * 0.1f, w * 0.9f, h * 0.8f);
        using (var path = Rounded(inner, h * 0.08f))
        using (var pen = new Pen(Color.FromArgb(200, BillLight), line * 0.7f)) g.DrawPath(pen, path);
        using (var font = new Font("Arial Black", h * 0.42f, FontStyle.Regular, GraphicsUnit.Pixel))
        using (var small = new Font("Arial Black", h * 0.13f, FontStyle.Regular, GraphicsUnit.Pixel))
        using (var light = new SolidBrush(BillLight))
        using (var dark = new SolidBrush(BillDark))
        {
            var center = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            foreach (float x in new[] { 0.17f, 0.83f })
            {
                g.DrawString("$", font, dark, new RectangleF(w * x - h * 0.3f + line * 0.6f, h * 0.2f + line * 0.6f, h * 0.6f, h * 0.6f), center);
                g.DrawString("$", font, light, new RectangleF(w * x - h * 0.3f, h * 0.2f, h * 0.6f, h * 0.6f), center);
            }
            foreach (float x in new[] { 0.09f, 0.91f })
                foreach (float y in new[] { 0.2f, 0.8f })
                    g.DrawString("1", small, dark, new RectangleF(w * x - h * 0.1f, h * y - h * 0.1f, h * 0.2f, h * 0.2f), center);
        }
        // The oval portrait, with the noob in it like the face on a real bill
        var oval = new RectangleF(w * 0.29f, h * 0.07f, w * 0.42f, h * 0.86f);
        using (var ovalPath = new GraphicsPath())
        {
            ovalPath.AddEllipse(oval);
            using (var fill = new SolidBrush(BillLight)) g.FillPath(fill, ovalPath);
            var clip = g.Clip;
            g.SetClip(ovalPath, CombineMode.Intersect);
            float side = oval.Height * 1.2f;
            g.DrawImage(noob, new RectangleF(oval.X + oval.Width / 2 - side / 2, oval.Y - oval.Height * 0.02f, side, side));
            g.Clip = clip;
            using (var pen = new Pen(BillDark, line * 1.2f)) g.DrawPath(pen, ovalPath);
        }
    }

    // A bill drawn at `x, y` (its middle), turned `angle` degrees, with a soft shadow
    static void PlaceBill(Graphics g, float x, float y, float w, float angle, Bitmap noob)
    {
        var state = g.Save();
        g.TranslateTransform(x, y);
        g.RotateTransform(angle);
        g.TranslateTransform(-w / 2, -w / 4);
        using (var shadowPath = Rounded(new RectangleF(w * 0.02f, w * 0.03f, w, w / 2), w * 0.06f))
        using (var shadow = new SolidBrush(Color.FromArgb(90, 0, 0, 0))) g.FillPath(shadow, shadowPath);
        DrawBill(g, w, noob);
        g.Restore(state);
    }

    static void OutlinedText(Graphics g, string text, float size, RectangleF box, Color fill, Color edge, float edgeWidth)
    {
        using (var path = new GraphicsPath())
        using (var family = new FontFamily("Arial Black"))
        {
            var fmt = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            path.AddString(text, family, (int)FontStyle.Regular, size, box, fmt);
            using (var pen = new Pen(edge, edgeWidth) { LineJoin = LineJoin.Round }) g.DrawPath(pen, path);
            using (var brush = new SolidBrush(fill)) g.FillPath(brush, path);
        }
    }

    static Graphics Prepare(Bitmap bmp)
    {
        var g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        return g;
    }

    // The logo: one bill on a see-through background
    public static void Logo(Bitmap noob, string outPath)
    {
        using (var bmp = new Bitmap(512, 512, PixelFormat.Format32bppArgb))
        using (var g = Prepare(bmp))
        {
            PlaceBill(g, 256, 256, 480, 0, noob);
            bmp.Save(outPath, ImageFormat.Png);
        }
    }

    // A pack picture: purple rays, "NOOB BUCKS", a pile of bills, and "x25"
    public static void Pack(Bitmap noob, int bucks, int bills, string outPath)
    {
        using (var bmp = new Bitmap(512, 512, PixelFormat.Format32bppArgb))
        using (var g = Prepare(bmp))
        {
            var all = new Rectangle(0, 0, 512, 512);
            using (var bg = new SolidBrush(Color.FromArgb(88, 40, 150))) g.FillRectangle(bg, all);
            using (var ray = new SolidBrush(Color.FromArgb(110, 60, 180)))
                for (int i = 0; i < 16; i += 2)
                    g.FillPie(ray, -256, -256, 1024, 1024, i * 22.5f, 11.25f);
            using (var glowPath = new GraphicsPath())
            {
                glowPath.AddEllipse(-80, -80, 672, 672);
                using (var glow = new PathGradientBrush(glowPath) { CenterColor = Color.FromArgb(120, 210, 170, 255), SurroundColors = new[] { Color.FromArgb(150, 40, 10, 80) } })
                    g.FillRectangle(glow, all);
            }
            // The pile: more bills for bigger packs, fanned out
            var rng = new Random(bucks);
            for (int i = 0; i < bills; i++)
            {
                float t = bills == 1 ? 0.5f : (float)i / (bills - 1);
                float x = 256 + (t - 0.5f) * 90 + (float)(rng.NextDouble() - 0.5) * 20;
                float y = 285 - i * 12 + (float)(rng.NextDouble() - 0.5) * 10;
                float angle = (t - 0.5f) * 36 + (float)(rng.NextDouble() - 0.5) * 8;
                if (i == bills - 1) { x = 256; y = 262; angle = -6; }
                PlaceBill(g, x, y, 300, angle, noob);
            }
            OutlinedText(g, "NOOB BUCKS", 54, new RectangleF(0, 18, 512, 80), Color.White, Color.FromArgb(30, 20, 50), 12);
            OutlinedText(g, "x" + bucks, 96, new RectangleF(0, 390, 512, 120), Color.FromArgb(130, 235, 110), Color.FromArgb(25, 70, 30), 16);
            bmp.Save(outPath, ImageFormat.Png);
        }
    }
}
