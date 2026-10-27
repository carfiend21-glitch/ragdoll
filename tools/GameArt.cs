using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

// Draws the game's thumbnails, icon and Game Pass / Developer Product pictures.
// 3D things (the noob in any pose, the Mini Nuke, TNT, the saw) are rendered from the
// same shapes, sizes and colors as the game (src/server/Noob.luau, src/shared/ItemModels.luau),
// with Roblox's own classic head and face. Effects (explosions, beams, the black hole)
// are painted on top in 2D.
public static class GameArt
{
    // ------------------------------------------------------------------
    // 3D maths
    // ------------------------------------------------------------------
    public struct V3
    {
        public double X, Y, Z;
        public V3(double x, double y, double z) { X = x; Y = y; Z = z; }
        public static V3 operator +(V3 a, V3 b) { return new V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z); }
        public static V3 operator -(V3 a, V3 b) { return new V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z); }
        public static V3 operator *(V3 a, double s) { return new V3(a.X * s, a.Y * s, a.Z * s); }
        public double Dot(V3 b) { return X * b.X + Y * b.Y + Z * b.Z; }
        public V3 Cross(V3 b) { return new V3(Y * b.Z - Z * b.Y, Z * b.X - X * b.Z, X * b.Y - Y * b.X); }
        public double Length() { return Math.Sqrt(Dot(this)); }
        public V3 Unit() { double m = Length(); return new V3(X / m, Y / m, Z / m); }
    }

    // A rotation (3x3 matrix, columns = where the X, Y and Z axes point)
    public struct M3
    {
        public V3 C0, C1, C2;
        public V3 Apply(V3 v) { return C0 * v.X + C1 * v.Y + C2 * v.Z; }
        public M3 Then(M3 inner) { return new M3 { C0 = Apply(inner.C0), C1 = Apply(inner.C1), C2 = Apply(inner.C2) }; }
        public static M3 Identity { get { return new M3 { C0 = new V3(1, 0, 0), C1 = new V3(0, 1, 0), C2 = new V3(0, 0, 1) }; } }
        // Degrees, like Roblox's CFrame.Angles (X, then Y, then Z)
        public static M3 Angles(double xDeg, double yDeg, double zDeg)
        {
            double x = xDeg * Math.PI / 180, y = yDeg * Math.PI / 180, z = zDeg * Math.PI / 180;
            var rx = new M3 { C0 = new V3(1, 0, 0), C1 = new V3(0, Math.Cos(x), Math.Sin(x)), C2 = new V3(0, -Math.Sin(x), Math.Cos(x)) };
            var ry = new M3 { C0 = new V3(Math.Cos(y), 0, -Math.Sin(y)), C1 = new V3(0, 1, 0), C2 = new V3(Math.Sin(y), 0, Math.Cos(y)) };
            var rz = new M3 { C0 = new V3(Math.Cos(z), Math.Sin(z), 0), C1 = new V3(-Math.Sin(z), Math.Cos(z), 0), C2 = new V3(0, 0, 1) };
            return rx.Then(ry).Then(rz);
        }
    }

    internal class Tri
    {
        public V3 A, B, C, NA, NB, NC;
        public Color Col;
        public int Id;
        public bool Face; // the noob's head: gets the smiley face on its front
        public bool Neon; // glows: no shading
        public V3 LA, LB, LC; // head-local positions, for placing the face
    }

    // ------------------------------------------------------------------
    // A 3D model made of Roblox-style parts
    // ------------------------------------------------------------------
    public class Model
    {
        internal List<Tri> Tris = new List<Tri>();
        int nextId = 1;
        public bool Neon; // parts added while this is on glow (like Roblox's Neon material)
        public string MeshPath, FacePath;

        void Add(V3 a, V3 b, V3 c, V3 na, V3 nb, V3 nc, Color col, int id)
        {
            Tris.Add(new Tri { A = a, B = b, C = c, NA = na, NB = nb, NC = nc, Col = col, Id = id, Neon = Neon });
        }

        public void Box(V3 center, M3 rot, V3 size, Color col)
        {
            int id = nextId++;
            double[] h = { size.X / 2, size.Y / 2, size.Z / 2 };
            V3[] axes = { new V3(1, 0, 0), new V3(0, 1, 0), new V3(0, 0, 1) };
            for (int a = 0; a < 3; a++)
                for (int s = -1; s <= 1; s += 2)
                {
                    V3 n = axes[a] * s;
                    V3 u = axes[(a + 1) % 3], v = axes[(a + 2) % 3];
                    double su = h[(a + 1) % 3], sv = h[(a + 2) % 3];
                    V3 c = n * h[a];
                    V3 p1 = c + u * su + v * sv, p2 = c - u * su + v * sv, p3 = c - u * su - v * sv, p4 = c + u * su - v * sv;
                    V3 wn = rot.Apply(n);
                    Add(center + rot.Apply(p1), center + rot.Apply(p2), center + rot.Apply(p3), wn, wn, wn, col, id);
                    Add(center + rot.Apply(p1), center + rot.Apply(p3), center + rot.Apply(p4), wn, wn, wn, col, id);
                }
        }

        // A Roblox cylinder: its length runs along its own X axis
        public void Cylinder(V3 center, M3 rot, double length, double diameter, Color col)
        {
            int id = nextId++, segs = 40;
            double r = diameter / 2, hl = length / 2;
            for (int i = 0; i < segs; i++)
            {
                double a0 = i * 2 * Math.PI / segs, a1 = (i + 1) * 2 * Math.PI / segs;
                V3 d0 = new V3(0, Math.Cos(a0), Math.Sin(a0)), d1 = new V3(0, Math.Cos(a1), Math.Sin(a1));
                V3 p0 = d0 * r, p1 = d1 * r, end = new V3(hl, 0, 0);
                V3 q00 = center + rot.Apply(p0 - end), q01 = center + rot.Apply(p0 + end), q10 = center + rot.Apply(p1 - end), q11 = center + rot.Apply(p1 + end);
                V3 n0 = rot.Apply(d0), n1 = rot.Apply(d1);
                Add(q00, q01, q11, n0, n0, n1, col, id);
                Add(q00, q11, q10, n0, n1, n1, col, id);
                V3 capA = rot.Apply(new V3(1, 0, 0)), capB = capA * -1;
                Add(center + rot.Apply(end), q01, q11, capA, capA, capA, col, id);
                Add(center - rot.Apply(end), q00, q10, capB, capB, capB, col, id);
            }
        }

        public void Ball(V3 center, double diameter, Color col)
        {
            int id = nextId++, rings = 24, segs = 40;
            double r = diameter / 2;
            Func<int, int, V3> dir = (i, j) =>
            {
                double t = i * Math.PI / rings, p = j * 2 * Math.PI / segs;
                return new V3(Math.Sin(t) * Math.Cos(p), Math.Cos(t), Math.Sin(t) * Math.Sin(p));
            };
            for (int i = 0; i < rings; i++)
                for (int j = 0; j < segs; j++)
                {
                    V3 a = dir(i, j), b = dir(i + 1, j), c = dir(i + 1, j + 1), d = dir(i, j + 1);
                    Add(center + a * r, center + b * r, center + c * r, a, b, c, col, id);
                    Add(center + a * r, center + c * r, center + d * r, a, c, d, col, id);
                }
        }

        // Roblox's classic head mesh with the smiley face on its front (-Z)
        public void Head(V3 center, M3 rot, double width, Color col)
        {
            int id = nextId++;
            byte[] data = File.ReadAllBytes(MeshPath);
            int start = Array.IndexOf(data, (byte)'\n') + 1;
            int headerSize = BitConverter.ToUInt16(data, start);
            int vertexSize = data[start + 2], faceSize = data[start + 3];
            int nv = BitConverter.ToInt32(data, start + 4), nf = BitConverter.ToInt32(data, start + 8);
            int p = start + headerSize;
            var pos = new V3[nv]; var nor = new V3[nv];
            for (int i = 0; i < nv; i++)
            {
                int o = p + i * vertexSize;
                pos[i] = new V3(BitConverter.ToSingle(data, o), BitConverter.ToSingle(data, o + 4), BitConverter.ToSingle(data, o + 8));
                nor[i] = new V3(BitConverter.ToSingle(data, o + 12), BitConverter.ToSingle(data, o + 16), BitConverter.ToSingle(data, o + 20));
            }
            double fit = width / 1.2; // the mesh is 1.2 studs across
            int fo = p + nv * vertexSize;
            for (int i = 0; i < nf; i++)
            {
                int o = fo + i * faceSize;
                int a = BitConverter.ToInt32(data, o), b = BitConverter.ToInt32(data, o + 4), c = BitConverter.ToInt32(data, o + 8);
                Tris.Add(new Tri
                {
                    A = center + rot.Apply(pos[a] * fit), B = center + rot.Apply(pos[b] * fit), C = center + rot.Apply(pos[c] * fit),
                    NA = rot.Apply(nor[a]), NB = rot.Apply(nor[b]), NC = rot.Apply(nor[c]),
                    Col = col, Id = id, Face = true, LA = pos[a] * (1 / 1.2), LB = pos[b] * (1 / 1.2), LC = pos[c] * (1 / 1.2),
                });
            }
        }
    }

    public static Color Yellow = Color.FromArgb(245, 205, 48), Blue = Color.FromArgb(13, 105, 172), Green = Color.FromArgb(164, 189, 71);

    // The classic noob, posed like a ragdoll. `torso` = how the torso is turned (degrees);
    // the others = how far each limb swings out round its joint (degrees, as seen from the front).
    public static Model Noob(string meshPath, string facePath, double tx, double ty, double tz,
        double head, double leftArm, double rightArm, double leftLeg, double rightLeg)
    {
        var m = new Model { MeshPath = meshPath, FacePath = facePath };
        M3 t = M3.Angles(tx, ty, tz);
        m.Box(new V3(0, 0, 0), t, new V3(2, 2, 1), Blue);
        // Each limb hangs from its joint and swings round the axis facing the camera
        Action<V3, V3, double, V3, Color, bool> limb = (joint, hang, angle, size, col, isHead) =>
        {
            M3 r = t.Then(M3.Angles(0, 0, angle));
            V3 c = t.Apply(joint) + r.Apply(hang);
            if (isHead) m.Head(c, r, 1.25, col); else m.Box(c, r, size, col);
        };
        limb(new V3(0, 1, 0), new V3(0, 0.5, 0), head, new V3(0, 0, 0), Yellow, true);
        limb(new V3(-1.5, 0.5, 0), new V3(0, -0.5, 0), -leftArm, new V3(1, 2, 1), Yellow, false);
        limb(new V3(1.5, 0.5, 0), new V3(0, -0.5, 0), rightArm, new V3(1, 2, 1), Yellow, false);
        limb(new V3(-0.5, -1, 0), new V3(0, -1, 0), -leftLeg, new V3(1, 2, 1), Green, false);
        limb(new V3(0.5, -1, 0), new V3(0, -1, 0), rightLeg, new V3(1, 2, 1), Green, false);
        return m;
    }

    // The Mini Nuke, from src/shared/ItemModels.luau (standing up)
    public static Model MiniNuke()
    {
        var m = new Model();
        Color gold = Color.FromArgb(240, 200, 40), black = Color.FromArgb(35, 37, 42);
        M3 upright = M3.Angles(0, 0, 90);
        m.Cylinder(new V3(0, -0.1, 0), upright, 2.2, 1.7, gold);
        m.Ball(new V3(0, 0.95, 0), 1.7, gold);
        m.Cylinder(new V3(0, -0.7, 0), upright, 0.3, 1.82, black);
        m.Box(new V3(-0.95, -1.25, 0), M3.Identity, new V3(0.15, 0.7, 1.4), black);
        m.Box(new V3(0.95, -1.25, 0), M3.Identity, new V3(0.15, 0.7, 1.4), black);
        m.Box(new V3(0, -1.25, 0.6), M3.Angles(0, 90, 0), new V3(0.15, 0.7, 1.2), black);
        return m;
    }

    // Big TNT: three red sticks with a black band
    public static Model BigTNT()
    {
        var m = new Model();
        Color red = Color.FromArgb(200, 35, 30);
        M3 upright = M3.Angles(0, 0, 90);
        foreach (double x in new[] { -0.9, 0.0, 0.9 }) m.Cylinder(new V3(x, -0.1, 0), upright, 2.2, 0.85, red);
        m.Box(new V3(0, 0.2, 0), M3.Identity, new V3(2.8, 0.3, 1), Color.FromArgb(40, 40, 40));
        m.Box(new V3(0.05, 1.25, 0), M3.Angles(0, 0, 20), new V3(0.1, 0.6, 0.1), Color.FromArgb(230, 220, 190));
        return m;
    }

    // The spinning saw blade, facing the camera
    public static Model Saw(double spin)
    {
        var m = new Model();
        Color steel = Color.FromArgb(200, 205, 215);
        M3 forward = M3.Angles(0, 90, 0);
        m.Cylinder(new V3(0, 0, 0), forward, 0.25, 4.4, steel);
        m.Cylinder(new V3(0, 0, 0.05), forward, 0.35, 1, Color.FromArgb(200, 40, 40));
        for (int i = 1; i <= 12; i++)
        {
            double a = i * 30 + spin;
            M3 r = M3.Angles(0, 0, a);
            m.Box(r.Apply(new V3(0, 2.25, 0)), r.Then(M3.Angles(0, 0, 45)), new V3(0.5, 0.5, 0.2), Color.FromArgb(170, 175, 185));
        }
        return m;
    }

    // ------------------------------------------------------------------
    // Rendering: a model to a see-through picture, with cartoon outlines
    // ------------------------------------------------------------------
    static double[] lastCam; // for Project()

    // `size` pixels square. The camera sits at `from` looking at `look`. `line` = outline thickness.
    public static Bitmap Render(Model model, int size, V3 from, V3 look, double fov, int line)
    {
        Bitmap face = model.FacePath != null ? new Bitmap(model.FacePath) : null;
        int ss = 2, W = size * ss;
        double[] depth = new double[W * W]; int[] ids = new int[W * W]; Color[] cols = new Color[W * W];
        for (int i = 0; i < depth.Length; i++) depth[i] = double.MaxValue;
        V3 fwd = (look - from).Unit(), right = fwd.Cross(new V3(0, 1, 0)).Unit(), up = right.Cross(fwd);
        double f = 1 / Math.Tan(fov * Math.PI / 360);
        lastCam = new double[] { from.X, from.Y, from.Z, fwd.X, fwd.Y, fwd.Z, right.X, right.Y, right.Z, up.X, up.Y, up.Z, f, size };
        V3 light = (fwd * -1 + up * 0.9 - right * 0.6).Unit();
        Func<V3, double[]> project = q =>
        {
            V3 d = q - from; double z = d.Dot(fwd);
            return new double[] { (d.Dot(right) * f / z * 0.5 + 0.5) * W, (0.5 - d.Dot(up) * f / z * 0.5) * W, z };
        };
        foreach (var t in model.Tris)
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
                    double shade = t.Neon ? 1.1 : 0.62 + 0.5 * Math.Max(0, n.Dot(light));
                    Color baseCol = t.Col;
                    if (t.Face && face != null)
                    {
                        V3 q = t.LA * w0 + t.LB * w1 + t.LC * w2; // in the head's own space, -0.5..0.5
                        if (q.Z < -0.15)
                        {
                            int fx = (int)((0.5 - q.X) * (face.Width - 1)), fy = (int)((0.5 - q.Y) * (face.Height - 1));
                            if (fx >= 0 && fy >= 0 && fx < face.Width && fy < face.Height)
                            {
                                Color fc = face.GetPixel(fx, fy);
                                double al = fc.A / 255.0;
                                baseCol = Color.FromArgb((int)(baseCol.R * (1 - al) + fc.R * al), (int)(baseCol.G * (1 - al) + fc.G * al), (int)(baseCol.B * (1 - al) + fc.B * al));
                            }
                        }
                    }
                    depth[i] = z; ids[i] = t.Id;
                    cols[i] = Color.FromArgb(Clamp(baseCol.R * shade), Clamp(baseCol.G * shade), Clamp(baseCol.B * shade));
                }
        }
        int ln = line * ss;
        Color ink = Color.FromArgb(25, 25, 35);
        bool[] filled = new bool[W * W];
        Color[] outCols = (Color[])cols.Clone();
        for (int y = 0; y < W; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x, id = ids[i];
                bool edge = false, any = id != 0;
                for (int dy = -ln; dy <= ln && !edge; dy++)
                    for (int dx = -ln; dx <= ln; dx++)
                    {
                        if (dx * dx + dy * dy > ln * ln) continue;
                        int xx = x + dx, yy = y + dy;
                        int other = (xx < 0 || yy < 0 || xx >= W || yy >= W) ? 0 : ids[yy * W + xx];
                        if (other != 0) any = true;
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

    // Where a 3D point shows up in the last Render (pixels)
    public static PointF Project(V3 q)
    {
        var c = lastCam;
        V3 from = new V3(c[0], c[1], c[2]), fwd = new V3(c[3], c[4], c[5]), right = new V3(c[6], c[7], c[8]), up = new V3(c[9], c[10], c[11]);
        double f = c[12], size = c[13];
        V3 d = q - from; double z = d.Dot(fwd);
        return new PointF((float)((d.Dot(right) * f / z * 0.5 + 0.5) * size), (float)((0.5 - d.Dot(up) * f / z * 0.5) * size));
    }

    static int Clamp(double v) { return Math.Max(0, Math.Min(255, (int)v)); }

    // A noob render that fills its picture: camera straight in front, slightly to one side
    public static Bitmap RenderNoob(Model noob, int size, double zoom)
    {
        V3 look = new V3(0, -0.4, 0);
        V3 dir = new V3(0.15, 0.1, -1).Unit();
        return Render(noob, size, look + dir * (13 / zoom), look, 30, 3);
    }

    // ------------------------------------------------------------------
    // 2D painting
    // ------------------------------------------------------------------
    public static Graphics Prepare(Bitmap bmp)
    {
        var g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.CompositingQuality = CompositingQuality.HighQuality;
        return g;
    }

    // Draws `img` with its middle at `x, y`, `w` wide, turned `angle` degrees
    public static void Place(Graphics g, Image img, float x, float y, float w, float angle)
    {
        var state = g.Save();
        g.TranslateTransform(x, y);
        g.RotateTransform(angle);
        float h = w * img.Height / img.Width;
        g.DrawImage(img, -w / 2, -h / 2, w, h);
        g.Restore(state);
    }

    // Big chunky game-style text: a thick dark outline, a drop shadow, and a gradient fill
    public static void Title(Graphics g, string text, string font, float size, RectangleF box, Color top, Color bottom, Color edge, float edgeWidth, StringAlignment align, float angle)
    {
        var state = g.Save();
        float cx = box.X + box.Width / 2, cy = box.Y + box.Height / 2;
        g.TranslateTransform(cx, cy);
        g.RotateTransform(angle);
        g.TranslateTransform(-cx, -cy);
        using (var path = new GraphicsPath())
        using (var family = new FontFamily(font))
        {
            // Laid out from a point (a layout box would cut off text that doesn't fit),
            // then moved into the box: left, middle or right, and centered up and down
            path.AddString(text, family, (int)FontStyle.Regular, size, new PointF(0, 0), StringFormat.GenericTypographic);
            RectangleF tb = path.GetBounds();
            float tx = align == StringAlignment.Near ? box.X : align == StringAlignment.Center ? box.X + (box.Width - tb.Width) / 2 : box.Right - tb.Width;
            var move = new Matrix();
            move.Translate(tx - tb.X, box.Y + (box.Height - tb.Height) / 2 - tb.Y);
            path.Transform(move);
            using (var shadow = (GraphicsPath)path.Clone())
            {
                var m = new Matrix(); m.Translate(edgeWidth * 0.35f, edgeWidth * 0.45f); shadow.Transform(m);
                using (var pen = new Pen(Color.FromArgb(160, 0, 0, 0), edgeWidth) { LineJoin = LineJoin.Round }) g.DrawPath(pen, shadow);
            }
            using (var pen = new Pen(edge, edgeWidth) { LineJoin = LineJoin.Round }) g.DrawPath(pen, path);
            RectangleF b = path.GetBounds();
            using (var fill = new LinearGradientBrush(new RectangleF(b.X, b.Y - 1, b.Width + 1, b.Height + 2), top, bottom, 90f)) g.FillPath(fill, path);
        }
        g.Restore(state);
    }

    // A cartoon explosion: smoke, a spiky orange fireball, a yellow core and flying sparks
    public static void Explosion(Graphics g, float x, float y, float r, int seed)
    {
        var rng = new Random(seed);
        for (int i = 0; i < 9; i++)
        {
            double a = rng.NextDouble() * Math.PI * 2; float d = r * (0.55f + (float)rng.NextDouble() * 0.45f), s = r * (0.35f + (float)rng.NextDouble() * 0.3f);
            using (var smoke = new SolidBrush(Color.FromArgb(200, 70 + rng.Next(30), 65 + rng.Next(25), 70 + rng.Next(25))))
                g.FillEllipse(smoke, x + (float)Math.Cos(a) * d - s, y + (float)Math.Sin(a) * d - s, s * 2, s * 2);
        }
        Action<float, Color, Color> spiky = (radius, outer, inner) =>
        {
            int points = 16; var pts = new PointF[points * 2];
            for (int i = 0; i < points * 2; i++)
            {
                double a = i * Math.PI / points + rng.NextDouble() * 0.15;
                float rr = (i % 2 == 0 ? radius : radius * 0.68f) * (0.9f + (float)rng.NextDouble() * 0.2f);
                pts[i] = new PointF(x + (float)Math.Cos(a) * rr, y + (float)Math.Sin(a) * rr);
            }
            using (var path = new GraphicsPath())
            {
                path.AddPolygon(pts);
                using (var brush = new PathGradientBrush(path) { CenterPoint = new PointF(x, y), CenterColor = inner, SurroundColors = new[] { outer } })
                    g.FillPath(brush, path);
            }
        };
        spiky(r, Color.FromArgb(235, 90, 20), Color.FromArgb(255, 170, 40));
        spiky(r * 0.72f, Color.FromArgb(255, 150, 30), Color.FromArgb(255, 235, 120));
        spiky(r * 0.42f, Color.FromArgb(255, 230, 110), Color.White);
        using (var pen = new Pen(Color.FromArgb(255, 220, 120), r * 0.035f) { StartCap = LineCap.Round, EndCap = LineCap.Triangle })
            for (int i = 0; i < 14; i++)
            {
                double a = rng.NextDouble() * Math.PI * 2; float d0 = r * 1.05f, d1 = r * (1.2f + (float)rng.NextDouble() * 0.5f);
                g.DrawLine(pen, x + (float)Math.Cos(a) * d0, y + (float)Math.Sin(a) * d0, x + (float)Math.Cos(a) * d1, y + (float)Math.Sin(a) * d1);
            }
    }

    // A glowing beam (laser, freeze ray, railgun)
    public static void Beam(Graphics g, PointF a, PointF b, float width, Color color)
    {
        for (int i = 4; i >= 1; i--)
            using (var pen = new Pen(Color.FromArgb(40 + (4 - i) * 30, color), width * i * 0.8f) { StartCap = LineCap.Round, EndCap = LineCap.Round })
                g.DrawLine(pen, a, b);
        using (var core = new Pen(Color.FromArgb(255, 255, 245, 245), width * 0.45f) { StartCap = LineCap.Round, EndCap = LineCap.Round }) g.DrawLine(core, a, b);
        Glow(g, b.X, b.Y, width * 3.5f, color);
    }

    // A soft round glow
    // (`whiteHot` = white in the middle; otherwise the glow's own color all the way)
    public static void Glow(Graphics g, float x, float y, float r, Color color, bool whiteHot = true)
    {
        using (var path = new GraphicsPath())
        {
            path.AddEllipse(x - r, y - r, r * 2, r * 2);
            using (var brush = new PathGradientBrush(path) { CenterColor = whiteHot ? Color.FromArgb(230, Color.White) : Color.FromArgb(170, color), SurroundColors = new[] { Color.FromArgb(0, color) } })
                g.FillPath(brush, path);
        }
    }

    // A jagged lightning bolt
    public static void Lightning(Graphics g, PointF a, PointF b, float width, Color color, int seed)
    {
        var rng = new Random(seed);
        int n = 9; var pts = new PointF[n + 1];
        float dx = b.X - a.X, dy = b.Y - a.Y, len = (float)Math.Sqrt(dx * dx + dy * dy);
        for (int i = 0; i <= n; i++)
        {
            float t = (float)i / n, j = (i == 0 || i == n) ? 0 : ((float)rng.NextDouble() - 0.5f) * len * 0.18f;
            pts[i] = new PointF(a.X + dx * t - dy / len * j, a.Y + dy * t + dx / len * j);
        }
        for (int i = 3; i >= 1; i--)
            using (var pen = new Pen(Color.FromArgb(60 + (3 - i) * 50, color), width * i) { LineJoin = LineJoin.Round })
                g.DrawLines(pen, pts);
        using (var core = new Pen(Color.White, width * 0.5f) { LineJoin = LineJoin.Round }) g.DrawLines(core, pts);
        Glow(g, b.X, b.Y, width * 6, color);
    }

    // The black hole: a swirling purple disc round a pitch-black middle
    public static void BlackHole(Graphics g, float x, float y, float r, float twist)
    {
        Glow(g, x, y, r * 1.4f, Color.FromArgb(150, 60, 230), false);
        for (int arm = 0; arm < 6; arm++)
        {
            var pts = new List<PointF>();
            for (int i = 0; i <= 60; i++)
            {
                float t = i / 60f; double a = arm * Math.PI / 3 + t * 4.2 + twist; float rr = r * (0.25f + t * 0.95f);
                pts.Add(new PointF(x + (float)Math.Cos(a) * rr, y + (float)Math.Sin(a) * rr * 0.85f));
            }
            using (var pen = new Pen(Color.FromArgb(200, arm % 2 == 0 ? Color.FromArgb(190, 90, 255) : Color.FromArgb(255, 120, 220)), r * 0.09f) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
                g.DrawCurve(pen, pts.ToArray());
        }
        using (var path = new GraphicsPath())
        {
            path.AddEllipse(x - r * 0.4f, y - r * 0.4f, r * 0.8f, r * 0.8f);
            using (var brush = new PathGradientBrush(path) { CenterColor = Color.Black, SurroundColors = new[] { Color.FromArgb(255, 40, 10, 60) } }) g.FillPath(brush, path);
        }
        using (var ring = new Pen(Color.FromArgb(230, 255, 200, 255), r * 0.03f)) g.DrawEllipse(ring, x - r * 0.42f, y - r * 0.42f, r * 0.84f, r * 0.84f);
    }

    // A mushroom cloud (the Mini Nuke going off)
    public static void Mushroom(Graphics g, float x, float ground, float h)
    {
        var rng = new Random(7);
        Glow(g, x, ground - h * 0.55f, h * 0.9f, Color.FromArgb(255, 200, 80));
        using (var stem = new LinearGradientBrush(new RectangleF(x - h * 0.12f, ground - h * 0.75f, h * 0.24f, h * 0.75f), Color.FromArgb(255, 150, 40), Color.FromArgb(200, 90, 40), 0f))
        {
            var pts = new[] { new PointF(x - h * 0.08f, ground - h * 0.65f), new PointF(x + h * 0.08f, ground - h * 0.65f), new PointF(x + h * 0.2f, ground), new PointF(x - h * 0.2f, ground) };
            g.FillPolygon(stem, pts);
        }
        for (int i = 0; i < 26; i++)
        {
            double a = rng.NextDouble() * Math.PI * 2; float d = h * 0.33f * (float)rng.NextDouble(), s = h * (0.12f + (float)rng.NextDouble() * 0.1f);
            float cx = x + (float)Math.Cos(a) * d * 1.5f, cy = ground - h * 0.72f + (float)Math.Sin(a) * d * 0.55f;
            int warm = rng.Next(60);
            using (var brush = new SolidBrush(Color.FromArgb(255, 200 + warm / 2, 90 + warm, 40)))
                g.FillEllipse(brush, cx - s, cy - s, s * 2, s * 2);
        }
        for (int i = 0; i < 12; i++)
        {
            double a = rng.NextDouble() * Math.PI * 2; float d = h * 0.2f * (float)rng.NextDouble(), s = h * (0.07f + (float)rng.NextDouble() * 0.05f);
            using (var brush = new SolidBrush(Color.FromArgb(255, 255, 240, 170)))
                g.FillEllipse(brush, x + (float)Math.Cos(a) * d * 1.4f - s, ground - h * 0.74f + (float)Math.Sin(a) * d * 0.5f - s, s * 2, s * 2);
        }
        // The ring of dust at the bottom
        for (int i = 0; i < 18; i++)
        {
            float t = i / 17f, cx = x - h * 0.7f + t * h * 1.4f, s = h * (0.07f + (float)rng.NextDouble() * 0.05f);
            using (var brush = new SolidBrush(Color.FromArgb(230, 230, 120 + rng.Next(60), 60)))
                g.FillEllipse(brush, cx - s, ground - s * 1.2f, s * 2, s * 2);
        }
    }

    // The radiation sign
    public static void Radiation(Graphics g, float x, float y, float r, Color fg, Color bg)
    {
        using (var b = new SolidBrush(bg)) g.FillEllipse(b, x - r, y - r, r * 2, r * 2);
        using (var f = new SolidBrush(fg))
        {
            for (int i = 0; i < 3; i++) g.FillPie(f, x - r * 0.88f, y - r * 0.88f, r * 1.76f, r * 1.76f, -90 + i * 120 - 30, 60);
            using (var b = new SolidBrush(bg)) g.FillEllipse(b, x - r * 0.28f, y - r * 0.28f, r * 0.56f, r * 0.56f);
            g.FillEllipse(f, x - r * 0.18f, y - r * 0.18f, r * 0.36f, r * 0.36f);
        }
    }

    // A side-on view of a test room, like the game's camera: back wall, a sliver of the
    // side walls, floor and ceiling, the stripe and the ROOM sign
    public static void Room(Graphics g, RectangleF r, string sign)
    {
        float side = r.Width * 0.035f, top = r.Height * 0.06f, floor = r.Height * 0.1f;
        using (var b = new SolidBrush(Color.FromArgb(175, 178, 185))) g.FillRectangle(b, r.X, r.Y, r.Width, top);
        using (var b = new SolidBrush(Color.FromArgb(95, 98, 105))) g.FillRectangle(b, r.X, r.Bottom - floor, r.Width, floor);
        using (var hatch = new HatchBrush(HatchStyle.DiagonalCross, Color.FromArgb(70, 255, 255, 255), Color.FromArgb(0, 0, 0, 0)))
            g.FillRectangle(hatch, r.X, r.Bottom - floor, r.Width, floor);
        var back = new RectangleF(r.X + side, r.Y + top, r.Width - side * 2, r.Height - top - floor);
        using (var b = new LinearGradientBrush(back, Color.FromArgb(240, 242, 246), Color.FromArgb(222, 225, 232), 90f)) g.FillRectangle(b, back);
        using (var b = new SolidBrush(Color.FromArgb(205, 208, 214)))
        {
            g.FillPolygon(b, new[] { new PointF(r.X, r.Y), new PointF(back.X, back.Y), new PointF(back.X, back.Bottom), new PointF(r.X, r.Bottom) });
            g.FillPolygon(b, new[] { new PointF(r.Right, r.Y), new PointF(back.Right, back.Y), new PointF(back.Right, back.Bottom), new PointF(r.Right, r.Bottom) });
        }
        using (var b = new SolidBrush(Color.FromArgb(150, 153, 160))) g.FillRectangle(b, back.X, back.Bottom - back.Height * 0.06f, back.Width, back.Height * 0.06f);
        if (sign != null)
        {
            float sw = back.Width * 0.36f, sh = back.Height * 0.12f;
            var sr = new RectangleF(back.X + back.Width / 2 - sw / 2, back.Y + back.Height * 0.03f, sw, sh);
            using (var b = new SolidBrush(Color.FromArgb(35, 40, 60))) g.FillRectangle(b, sr);
            using (var font = new Font("Arial Black", sh * 0.5f, GraphicsUnit.Pixel))
            using (var w = new SolidBrush(Color.White))
                g.DrawString(sign, font, w, sr, new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center });
        }
        using (var pen = new Pen(Color.FromArgb(25, 25, 35), Math.Max(2, r.Width * 0.004f))) g.DrawRectangle(pen, r.X, r.Y, r.Width, r.Height);
    }

    // Purple rays fanning out from a point (behind the big titles and icons)
    public static void Rays(Graphics g, RectangleF r, float cx, float cy, Color dark, Color light, int count)
    {
        using (var b = new SolidBrush(dark)) g.FillRectangle(b, r);
        float big = Math.Max(r.Width, r.Height) * 2;
        using (var b = new SolidBrush(light))
            for (int i = 0; i < count; i += 2)
                g.FillPie(b, cx - big, cy - big, big * 2, big * 2, i * 360f / count, 360f / count);
        using (var path = new GraphicsPath())
        {
            path.AddEllipse(cx - big / 2, cy - big / 2, big, big);
            using (var glow = new PathGradientBrush(path) { CenterPoint = new PointF(cx, cy), CenterColor = Color.FromArgb(80, 255, 245, 230), SurroundColors = new[] { Color.FromArgb(160, dark.R / 3, dark.G / 3, dark.B / 3) } })
                g.FillRectangle(glow, r);
        }
    }

    public static void Save(Bitmap bmp, string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        bmp.Save(path, ImageFormat.Png);
    }
}
