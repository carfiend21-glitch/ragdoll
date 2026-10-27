using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;

// The actual pictures: 5 thumbnails (1920x1080), the game icon (512x512) and the
// Game Pass / Developer Product pictures (512x512, everything important kept inside the
// circle Roblox crops pass icons to). Uses GameArt.cs.
public static class GameArtScenes
{
    static string mesh, face;
    static readonly Color Ink = Color.FromArgb(30, 20, 45);
    static readonly Color Gold1 = Color.FromArgb(255, 236, 120), Gold2 = Color.FromArgb(255, 165, 30);

    static Bitmap Noob(int size, double tx, double ty, double tz, double head, double la, double ra, double ll, double rl)
    {
        return GameArt.RenderNoob(GameArt.Noob(mesh, face, tx, ty, tz, head, la, ra, ll, rl), size, 1.0);
    }

    static Bitmap Thing(GameArt.Model model, int size, double fx, double fy, double fz, double fov)
    {
        return GameArt.Render(model, size, new GameArt.V3(fx, fy, fz), new GameArt.V3(0, 0, 0), fov, 3);
    }

    // A floating damage number, like the game's "-2,250 HEAD"
    static void Popup(Graphics g, string text, float x, float y, float size, Color fill, float angle)
    {
        GameArt.Title(g, text, "Arial Black", size, new RectangleF(x - 500, y - size, 1000, size * 2), Color.White, fill, Ink, size * 0.18f, StringAlignment.Center, angle);
    }

    static void Shade(Graphics g, Rectangle r, int alpha)
    {
        using (var b = new SolidBrush(Color.FromArgb(alpha, 10, 5, 25))) g.FillRectangle(b, r);
    }

    public static void MakeAll(string meshPath, string facePath, string root)
    {
        mesh = meshPath; face = facePath;
        string thumbs = Path.Combine(root, "images", "thumbnails");
        string passes = Path.Combine(root, "images", "game-passes");
        string products = Path.Combine(root, "images", "developer-products");
        Hero(Path.Combine(thumbs, "1-ragdoll-pvp.png"));
        Weapons(Path.Combine(thumbs, "2-30-weapons.png"));
        Nuke(Path.Combine(thumbs, "3-mini-nuke.png"));
        Void(Path.Combine(thumbs, "4-black-hole.png"));
        Players(Path.Combine(thumbs, "5-8-players.png"));
        Icon(Path.Combine(root, "images", "icon", "game-icon.png"));
        DoubleBucks(Path.Combine(passes, "2x-noob-bucks.png"), Path.Combine(products, "noob-buck-logo.png"), false);
        DoubleBucks(Path.Combine(products, "2x-noob-bucks-1-hour.png"), Path.Combine(products, "noob-buck-logo.png"), true);
        VoidPass(Path.Combine(passes, "black-hole.png"));
        NukePass(Path.Combine(passes, "mini-nuke.png"));
    }

    // The noob without its left arm (it's just popped off)
    static Bitmap NoobNoLeftArm(int size, double tx, double ty, double tz, double head, double ra, double ll, double rl)
    {
        var m = new GameArt.Model { MeshPath = mesh, FacePath = face };
        var t = GameArt.M3.Angles(tx, ty, tz);
        m.Box(new GameArt.V3(0, 0, 0), t, new GameArt.V3(2, 2, 1), GameArt.Blue);
        Action<GameArt.V3, GameArt.V3, double, Color, bool> limb = (joint, hang, angle, col, isHead) =>
        {
            var r = t.Then(GameArt.M3.Angles(0, 0, angle));
            var c = t.Apply(joint) + r.Apply(hang);
            if (isHead) m.Head(c, r, 1.25, col); else m.Box(c, r, new GameArt.V3(1, 2, 1), col);
        };
        limb(new GameArt.V3(0, 1, 0), new GameArt.V3(0, 0.5, 0), head, GameArt.Yellow, true);
        limb(new GameArt.V3(1.5, 0.5, 0), new GameArt.V3(0, -0.5, 0), ra, GameArt.Yellow, false);
        limb(new GameArt.V3(-0.5, -1, 0), new GameArt.V3(0, -1, 0), -ll, GameArt.Green, false);
        limb(new GameArt.V3(0.5, -1, 0), new GameArt.V3(0, -1, 0), rl, GameArt.Green, false);
        return GameArt.RenderNoob(m, size, 1.0);
    }

    // Dark edges, so the eye goes straight to the middle
    static void Vignette(Graphics g, int width, int height, int alpha)
    {
        using (var path = new GraphicsPath())
        {
            path.AddEllipse(width / 2f - width * 0.75f, height / 2f - height * 0.8f, width * 1.5f, height * 1.6f);
            using (var brush = new PathGradientBrush(path) { CenterColor = Color.FromArgb(0, 0, 0, 0), SurroundColors = new[] { Color.FromArgb(alpha, 5, 0, 15) }, FocusScales = new PointF(0.45f, 0.45f) })
                g.FillRectangle(brush, 0, 0, width, height);
        }
    }

    // 1. The game in one picture: the room in darkness, lit only by a huge blast, and the
    // noob blasted toward the camera with an arm popping off, debris and a shockwave flying
    static void Hero(string path)
    {
        using (var bmp = new Bitmap(1920, 1080))
        using (var g = GameArt.Prepare(bmp))
        {
            var rng = new Random(11);
            float bx = 400, by = 850; // the blast
            GameArt.Room(g, new RectangleF(0, 0, 1920, 1080), null);
            Shade(g, new Rectangle(0, 0, 1920, 1080), 225);
            // The blast lights up the room near it in orange; the far side stays dark
            GameArt.Glow(g, bx, by, 950, Color.FromArgb(255, 110, 25), false);
            GameArt.Glow(g, bx, by, 560, Color.FromArgb(255, 200, 90));
            // Speed lines streaking away from the blast
            for (int i = 0; i < 46; i++)
            {
                double a = -1.35 + rng.NextDouble() * 1.45; // up and to the right
                float d0 = 250 + (float)rng.NextDouble() * 350, d1 = d0 + 300 + (float)rng.NextDouble() * 700;
                using (var pen = new Pen(Color.FromArgb(40 + rng.Next(90), 255, 235, 200), 3 + (float)rng.NextDouble() * 7) { StartCap = LineCap.Triangle, EndCap = LineCap.Round })
                    g.DrawLine(pen, bx + (float)Math.Cos(a) * d0, by + (float)Math.Sin(a) * d0, bx + (float)Math.Cos(a) * d1, by + (float)Math.Sin(a) * d1);
            }
            // The shockwave ring
            using (var pen = new Pen(Color.FromArgb(150, 255, 240, 200), 22)) g.DrawEllipse(pen, bx - 640, by - 430, 1280, 860);
            using (var pen = new Pen(Color.FromArgb(90, 255, 255, 255), 8)) g.DrawEllipse(pen, bx - 700, by - 470, 1400, 940);
            GameArt.Explosion(g, bx, by, 400, 3);
            // Bits of debris flying out, with little streaks behind them
            for (int i = 0; i < 26; i++)
            {
                double a = -1.4 + rng.NextDouble() * 1.6;
                float d = 450 + (float)rng.NextDouble() * 900, s = 10 + (float)rng.NextDouble() * 26;
                float x = bx + (float)Math.Cos(a) * d, y = by + (float)Math.Sin(a) * d;
                using (var pen = new Pen(Color.FromArgb(70, 255, 220, 170), s * 0.5f)) g.DrawLine(pen, x, y, x - (float)Math.Cos(a) * s * 4, y - (float)Math.Sin(a) * s * 4);
                var state = g.Save();
                g.TranslateTransform(x, y);
                g.RotateTransform(rng.Next(360));
                int shade = 50 + rng.Next(60);
                using (var b = new SolidBrush(Color.FromArgb(shade, shade, shade + 8))) g.FillRectangle(b, -s / 2, -s / 3, s, s * 0.66f);
                using (var pen = new Pen(Color.FromArgb(255, 170, 70), 2)) g.DrawRectangle(pen, -s / 2, -s / 3, s, s * 0.66f);
                g.Restore(state);
            }
            // The noob, blasted right at the camera, lit from behind
            GameArt.Glow(g, 1180, 560, 430, Color.FromArgb(255, 90, 20), false);
            using (var noob = NoobNoLeftArm(1000, 15, 35, -25, 25, 70, 55, -40)) GameArt.Place(g, noob, 1240, 500, 1050, -14);
            // ...and its arm, popping off
            var arm = new GameArt.Model();
            arm.Box(new GameArt.V3(0, 0, 0), GameArt.M3.Angles(20, 30, 0), new GameArt.V3(1, 2, 1), GameArt.Yellow);
            using (var img = GameArt.Render(arm, 500, new GameArt.V3(1.2, 1, -6), new GameArt.V3(0, 0, 0), 32, 3))
                GameArt.Place(g, img, 1720, 840, 380, 48);
            GameArt.Glow(g, 1620, 760, 90, Color.FromArgb(255, 240, 150));
            Vignette(g, 1920, 1080, 250);

            Popup(g, "POP!", 1760, 690, 92, Color.FromArgb(255, 80, 60), 12);
            Popup(g, "-12,500 TORSO!", 1580, 75, 68, Color.FromArgb(255, 90, 40), -4);
            Popup(g, "COMBO x8!", 1020, 980, 70, Color.FromArgb(255, 210, 40), -3);
            GameArt.Title(g, "RAGDOLL", "Arial Black", 165, new RectangleF(30, 30, 900, 230), Gold1, Gold2, Ink, 26, StringAlignment.Near, -4);
            GameArt.Title(g, "PVP", "Arial Black", 240, new RectangleF(60, 225, 700, 270), Color.FromArgb(255, 110, 80), Color.FromArgb(200, 20, 20), Ink, 30, StringAlignment.Near, -4);
            GameArt.Save(bmp, path);
        }
    }

    // 2. Lots of weapons at once: a laser, lightning, a saw and an explosion
    static void Weapons(string path)
    {
        using (var bmp = new Bitmap(1920, 1080))
        using (var g = GameArt.Prepare(bmp))
        {
            GameArt.Room(g, new RectangleF(0, 0, 1920, 1080), null);
            using (var saw = Thing(GameArt.Saw(10), 500, 0, 0, -9, 32)) GameArt.Place(g, saw, 1640, 640, 460, 0);
            using (var tnt = Thing(GameArt.BigTNT(), 300, 2, 1.2, -7, 35)) GameArt.Place(g, tnt, 330, 940, 220, 0);
            GameArt.Explosion(g, 360, 860, 210, 4);
            GameArt.Beam(g, new PointF(60, 520), new PointF(830, 620), 22, Color.FromArgb(255, 40, 40));
            GameArt.Lightning(g, new PointF(1330, 300), new PointF(1080, 520), 14, Color.FromArgb(120, 190, 255), 3);
            using (var noob = Noob(800, -15, -20, 35, -15, 70, 140, -30, 45)) GameArt.Place(g, noob, 980, 640, 600, 10);
            Popup(g, "-1,250 RIGHT LEG", 560, 440, 56, Color.FromArgb(255, 210, 40), -8);
            Popup(g, "-1,200 TORSO", 1330, 610, 56, Color.FromArgb(255, 210, 40), 6);
            GameArt.Title(g, "30 WEAPONS!", "Arial Black", 190, new RectangleF(0, 30, 1920, 230), Gold1, Gold2, Ink, 26, StringAlignment.Center, -3);
            using (var band = new SolidBrush(Color.FromArgb(200, 30, 20, 45))) g.FillRectangle(band, 0, 960, 1920, 120);
            GameArt.Title(g, "LASERS • SAWS • LIGHTNING • NUKES", "Arial Black", 70, new RectangleF(0, 965, 1920, 110), Color.White, Color.FromArgb(200, 220, 255), Ink, 12, StringAlignment.Center, 0);
            GameArt.Save(bmp, path);
        }
    }

    // 3. The Mini Nuke going off
    static void Nuke(string path)
    {
        using (var bmp = new Bitmap(1920, 1080))
        using (var g = GameArt.Prepare(bmp))
        {
            GameArt.Room(g, new RectangleF(0, 0, 1920, 1080), null);
            Shade(g, new Rectangle(0, 0, 1920, 1080), 90);
            GameArt.Mushroom(g, 1180, 975, 900);
            using (var noob = Noob(700, 20, 30, 60, 30, 150, 110, 60, 20)) GameArt.Place(g, noob, 1620, 300, 380, 25);
            using (var nuke = Thing(GameArt.MiniNuke(), 600, 2.2, 1.4, -7, 34))
            {
                using (var g2 = GameArt.Prepare(nuke))
                {
                    PointF c = GameArt.Project(new GameArt.V3(0, -0.05, -0.86)), e = GameArt.Project(new GameArt.V3(0.45, -0.05, -0.86));
                    GameArt.Radiation(g2, c.X, c.Y, Math.Abs(e.X - c.X), Color.FromArgb(25, 25, 25), Color.FromArgb(250, 210, 50));
                }
                GameArt.Place(g, nuke, 330, 760, 560, -8);
            }
            Popup(g, "-2,750 TORSO", 1560, 560, 66, Color.FromArgb(255, 210, 40), 5);
            GameArt.Title(g, "NUKE THE", "Arial Black", 150, new RectangleF(30, 30, 1100, 190), Gold1, Gold2, Ink, 24, StringAlignment.Near, -4);
            GameArt.Title(g, "NOOB!", "Arial Black", 210, new RectangleF(50, 190, 900, 250), Color.FromArgb(255, 245, 200), Color.FromArgb(255, 110, 30), Ink, 28, StringAlignment.Near, -4);
            GameArt.Save(bmp, path);
        }
    }

    // 4. The Black Hole sucking the noob in
    static void Void(string path)
    {
        using (var bmp = new Bitmap(1920, 1080))
        using (var g = GameArt.Prepare(bmp))
        {
            GameArt.Rays(g, new RectangleF(0, 0, 1920, 1080), 1180, 560, Color.FromArgb(15, 5, 30), Color.FromArgb(32, 12, 58), 28);
            Shade(g, new Rectangle(0, 0, 1920, 1080), 190);
            GameArt.BlackHole(g, 1180, 560, 470, 0.6f);
            using (var noob = Noob(700, -10, 40, -70, -40, 160, 20, 90, -60)) GameArt.Place(g, noob, 1420, 380, 420, -35);
            Popup(g, "-250 LEFT LEG", 1530, 820, 58, Color.FromArgb(220, 170, 255), 6);
            GameArt.Title(g, "INTO THE", "Arial Black", 140, new RectangleF(30, 40, 900, 180), Color.FromArgb(240, 220, 255), Color.FromArgb(190, 110, 255), Ink, 22, StringAlignment.Near, -4);
            GameArt.Title(g, "VOID!", "Arial Black", 230, new RectangleF(40, 200, 900, 270), Color.White, Color.FromArgb(200, 90, 255), Ink, 30, StringAlignment.Near, -4);
            GameArt.Title(g, "BLACK HOLE", "Arial Black", 70, new RectangleF(50, 470, 900, 110), Color.White, Color.FromArgb(255, 140, 220), Ink, 12, StringAlignment.Near, -4);
            GameArt.Save(bmp, path);
        }
    }

    // 5. Up to 8 players, each in their own room: who does the most damage?
    static void Players(string path)
    {
        using (var bmp = new Bitmap(1920, 1080))
        using (var g = GameArt.Prepare(bmp))
        {
            GameArt.Rays(g, new RectangleF(0, 0, 1920, 1080), 960, 600, Color.FromArgb(28, 18, 16), Color.FromArgb(48, 28, 22), 24);
            GameArt.Glow(g, 960, 600, 1100, Color.FromArgb(255, 100, 20), false);
            Vignette(g, 1920, 1080, 200);
            string[] names = { "ROOM 1", "ROOM 2", "ROOM 3", "ROOM 4" };
            string[] scores = { "152,400", "98,750", "121,300", "64,200" };
            double[][] poses = {
                new double[] { 10, 25, -30, 20, 130, 60, 40, -25 },
                new double[] { -10, -20, 60, -10, 40, 150, 20, 70 },
                new double[] { 5, 15, -120, 25, 100, 100, -20, 30 },
                new double[] { 0, 10, 15, 5, 30, 35, 10, 15 },
            };
            for (int i = 0; i < 4; i++)
            {
                float x = 70 + (i % 2) * 920, y = 225 + (i / 2) * 385;
                var r = new RectangleF(x, y, 860, 360);
                GameArt.Room(g, r, names[i]);
                g.SetClip(r); // keep each room's effects inside it
                if (i == 0) GameArt.Explosion(g, x + 230, y + 300, 120, 9);
                if (i == 1) GameArt.Beam(g, new PointF(x + 30, y + 160), new PointF(x + 400, y + 200), 12, Color.FromArgb(255, 40, 40));
                if (i == 2) GameArt.Lightning(g, new PointF(x + 600, y + 30), new PointF(x + 450, y + 150), 8, Color.FromArgb(120, 190, 255), 5);
                var p = poses[i];
                using (var noob = Noob(400, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7])) GameArt.Place(g, noob, x + 470, y + 205, 260, (float)(p[2] * 0.2));
                // Their score, bottom-left of the room
                GameArt.Title(g, scores[i] + " PTS", "Arial Black", 46, new RectangleF(x + 20, y + 300, 600, 70), Color.White, i == 0 ? Gold2 : Color.FromArgb(200, 210, 230), Ink, 9, StringAlignment.Near, 0);
                g.ResetClip();
                if (i == 0)
                {
                    using (var b = new SolidBrush(Gold2)) g.FillEllipse(b, x + 730, y - 40, 150, 150);
                    using (var pen = new Pen(Ink, 8)) g.DrawEllipse(pen, x + 730, y - 40, 150, 150);
                    GameArt.Title(g, "1ST", "Arial Black", 54, new RectangleF(x + 730, y - 40, 150, 150), Color.White, Color.FromArgb(255, 245, 200), Ink, 8, StringAlignment.Center, -10);
                }
            }
            GameArt.Title(g, "WHO DOES THE MOST DAMAGE?", "Arial Black", 96, new RectangleF(0, 20, 1920, 180), Gold1, Gold2, Ink, 18, StringAlignment.Center, 0);
            GameArt.Title(g, "8 PLAYERS • 90 SECOND ROUNDS", "Arial Black", 44, new RectangleF(0, 1000, 1920, 80), Color.White, Color.FromArgb(200, 220, 255), Ink, 8, StringAlignment.Center, 0);
            GameArt.Save(bmp, path);
        }
    }

    // The game icon: like the main thumbnail, shrunk to a square. A dark room lit by a
    // blast, and the noob blasted at the camera with an arm popping off. Kept simple and
    // bold, because it's often shown tiny.
    static void Icon(string path)
    {
        using (var bmp = new Bitmap(512, 512))
        using (var g = GameArt.Prepare(bmp))
        {
            var rng = new Random(5);
            float bx = 100, by = 330; // the blast
            GameArt.Room(g, new RectangleF(-40, -30, 592, 572), null);
            Shade(g, new Rectangle(0, 0, 512, 512), 225);
            GameArt.Glow(g, bx, by, 420, Color.FromArgb(255, 110, 25), false);
            GameArt.Glow(g, bx, by, 210, Color.FromArgb(255, 200, 90));
            for (int i = 0; i < 22; i++)
            {
                double a = -1.4 + rng.NextDouble() * 1.5;
                float d0 = 90 + (float)rng.NextDouble() * 90, d1 = d0 + 120 + (float)rng.NextDouble() * 260;
                using (var pen = new Pen(Color.FromArgb(50 + rng.Next(90), 255, 235, 200), 2 + (float)rng.NextDouble() * 3) { StartCap = LineCap.Triangle, EndCap = LineCap.Round })
                    g.DrawLine(pen, bx + (float)Math.Cos(a) * d0, by + (float)Math.Sin(a) * d0, bx + (float)Math.Cos(a) * d1, by + (float)Math.Sin(a) * d1);
            }
            using (var pen = new Pen(Color.FromArgb(140, 255, 240, 200), 8)) g.DrawEllipse(pen, bx - 230, by - 160, 460, 320);
            GameArt.Explosion(g, bx, by, 150, 3);
            GameArt.Glow(g, 300, 220, 190, Color.FromArgb(255, 90, 20), false);
            using (var noob = NoobNoLeftArm(700, 15, 35, -25, 25, 70, 55, -40)) GameArt.Place(g, noob, 300, 215, 440, -14);
            var arm = new GameArt.Model();
            arm.Box(new GameArt.V3(0, 0, 0), GameArt.M3.Angles(20, 30, 0), new GameArt.V3(1, 2, 1), GameArt.Yellow);
            using (var img = GameArt.Render(arm, 300, new GameArt.V3(1.2, 1, -6), new GameArt.V3(0, 0, 0), 32, 3))
                GameArt.Place(g, img, 462, 250, 120, 48);
            GameArt.Glow(g, 432, 222, 34, Color.FromArgb(255, 240, 150));
            Vignette(g, 512, 512, 240);
            GameArt.Title(g, "RAGDOLL", "Arial Black", 62, new RectangleF(0, 362, 512, 70), Gold1, Gold2, Ink, 13, StringAlignment.Center, -3);
            GameArt.Title(g, "PVP", "Arial Black", 70, new RectangleF(0, 425, 512, 80), Color.FromArgb(255, 110, 80), Color.FromArgb(200, 20, 20), Ink, 14, StringAlignment.Center, -3);
            GameArt.Save(bmp, path);
        }
    }

    // 2x Noob Bucks (the Game Pass, or the 1-hour boost)
    static void DoubleBucks(string path, string logoPath, bool oneHour)
    {
        using (var bmp = new Bitmap(512, 512))
        using (var g = GameArt.Prepare(bmp))
        using (var logo = new Bitmap(logoPath))
        {
            if (oneHour) GameArt.Rays(g, new RectangleF(0, 0, 512, 512), 256, 256, Color.FromArgb(20, 70, 120), Color.FromArgb(35, 110, 170), 20);
            else GameArt.Rays(g, new RectangleF(0, 0, 512, 512), 256, 256, Color.FromArgb(20, 90, 50), Color.FromArgb(40, 140, 75), 20);
            GameArt.Place(g, logo, 230, 300, 380, -12);
            GameArt.Place(g, logo, 280, 250, 380, 6);
            GameArt.Title(g, "2x", "Arial Black", 190, new RectangleF(0, 30, 512, 220), Gold1, Gold2, Ink, 22, StringAlignment.Center, -6);
            if (oneHour)
            {
                // A little stopwatch
                using (var b = new SolidBrush(Color.White)) g.FillEllipse(b, 330, 330, 110, 110);
                using (var pen = new Pen(Ink, 9)) g.DrawEllipse(pen, 330, 330, 110, 110);
                using (var hand = new Pen(Ink, 8) { StartCap = LineCap.Round, EndCap = LineCap.Round })
                {
                    g.DrawLine(hand, 385, 385, 385, 350);
                    g.DrawLine(hand, 385, 385, 410, 395);
                }
                using (var b = new SolidBrush(Ink)) g.FillRectangle(b, 375, 316, 20, 16);
                GameArt.Title(g, "1 HOUR", "Arial Black", 58, new RectangleF(40, 400, 300, 80), Color.White, Color.FromArgb(200, 230, 255), Ink, 10, StringAlignment.Center, 0);
            }
            else
            {
                GameArt.Title(g, "FOREVER", "Arial Black", 62, new RectangleF(0, 400, 512, 80), Color.White, Color.FromArgb(200, 255, 210), Ink, 10, StringAlignment.Center, 0);
            }
            GameArt.Save(bmp, path);
        }
    }

    // The 8 Noob Buck exclusive weapons: the weapon on glowing rays in its own color, with
    // its name underneath. `front` = seen from the front like the room camera sees it
    // (things that don't aim); otherwise from the side, like a gun.
    static readonly object[][] EXCLUSIVES = {
        new object[] { "GravityFlipper", "GRAVITY FLIPPER", Color.FromArgb(60, 20, 110), Color.FromArgb(110, 50, 190), true, 8.0 },
        new object[] { "FreezeRay", "FREEZE RAY", Color.FromArgb(20, 70, 120), Color.FromArgb(50, 140, 200), false, 7.8 },
        new object[] { "AcidBlaster", "ACID BLASTER", Color.FromArgb(25, 80, 20), Color.FromArgb(70, 160, 40), false, 7.8 },
        new object[] { "StormCloud", "STORM CLOUD", Color.FromArgb(25, 30, 60), Color.FromArgb(60, 70, 120), true, 15.0 },
        new object[] { "BanHammer", "BAN HAMMER", Color.FromArgb(110, 15, 15), Color.FromArgb(190, 40, 40), true, 15.0 },
        new object[] { "Railgun", "RAILGUN", Color.FromArgb(15, 40, 110), Color.FromArgb(40, 100, 210), false, 8.0 },
        new object[] { "Minigun", "MINIGUN", Color.FromArgb(50, 50, 55), Color.FromArgb(95, 95, 105), false, 8.2 },
        new object[] { "MissileSwarm", "MISSILE SWARM", Color.FromArgb(55, 65, 25), Color.FromArgb(105, 125, 50), false, 7.0 },
    };

    public static void MakeExclusives(string root)
    {
        string dir = Path.Combine(root, "images", "exclusive-weapons");
        foreach (var spec in EXCLUSIVES)
        {
            string id = (string)spec[0], name = (string)spec[1];
            Color dark = (Color)spec[2], light = (Color)spec[3];
            bool front = (bool)spec[4];
            double distance = (double)spec[5];
            using (var bmp = new Bitmap(512, 512))
            using (var g = GameArt.Prepare(bmp))
            {
                GameArt.Rays(g, new RectangleF(0, 0, 512, 512), 256, 230, dark, light, 20);
                GameArt.Glow(g, 256, 230, 200, light, false);
                var model = ExclusiveModels.Build(id);
                var dirV = front ? new GameArt.V3(0.35, 0.25, 1) : new GameArt.V3(1, 0.45, -0.55);
                var from = dirV.Unit() * distance;
                using (var img = GameArt.Render(model, 600, from, new GameArt.V3(0, 0, 0), 30, 3))
                {
                    if (id == "BanHammer")
                    {
                        // "BAN" on the front of the hammer head, like in the game
                        using (var g2 = GameArt.Prepare(img))
                        {
                            PointF c = GameArt.Project(new GameArt.V3(0, -1.55, 0.9));
                            GameArt.Title(g2, "BAN", "Arial Black", 70, new RectangleF(c.X - 150, c.Y - 45, 300, 90), Color.White, Color.FromArgb(230, 230, 230), Color.FromArgb(90, 10, 10), 6, StringAlignment.Center, 0);
                        }
                    }
                    GameArt.Place(g, img, 256, 215, 430, 0);
                }
                GameArt.Title(g, name, "Arial Black", name.Length > 12 ? 44 : 52, new RectangleF(10, 400, 492, 90), Color.White, Color.FromArgb(220, 225, 255), Ink, 10, StringAlignment.Center, 0);
                GameArt.Save(bmp, Path.Combine(dir, id + ".png"));
            }
        }
    }

    static void VoidPass(string path)
    {
        using (var bmp = new Bitmap(512, 512))
        using (var g = GameArt.Prepare(bmp))
        {
            using (var b = new SolidBrush(Color.FromArgb(18, 8, 35))) g.FillRectangle(b, 0, 0, 512, 512);
            GameArt.BlackHole(g, 256, 256, 210, 0.3f);
            using (var noob = Noob(500, -10, 40, -70, -40, 160, 20, 90, -60)) GameArt.Place(g, noob, 345, 175, 170, -35);
            GameArt.Save(bmp, path);
        }
    }

    static void NukePass(string path)
    {
        using (var bmp = new Bitmap(512, 512))
        using (var g = GameArt.Prepare(bmp))
        {
            GameArt.Rays(g, new RectangleF(0, 0, 512, 512), 256, 256, Color.FromArgb(150, 50, 10), Color.FromArgb(220, 110, 20), 20);
            GameArt.Glow(g, 256, 256, 230, Color.FromArgb(255, 220, 90));
            using (var nuke = Thing(GameArt.MiniNuke(), 600, 2.2, 1.4, -7, 34))
            {
                using (var g2 = GameArt.Prepare(nuke))
                {
                    PointF c = GameArt.Project(new GameArt.V3(0, -0.05, -0.86)), e = GameArt.Project(new GameArt.V3(0.45, -0.05, -0.86));
                    GameArt.Radiation(g2, c.X, c.Y, Math.Abs(e.X - c.X), Color.FromArgb(25, 25, 25), Color.FromArgb(250, 210, 50));
                }
                GameArt.Place(g, nuke, 256, 262, 420, -10);
            }
            GameArt.Save(bmp, path);
        }
    }
}
