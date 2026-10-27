using System;
using System.Drawing;

// The 8 Noob Buck exclusive weapons, copied part by part from their builders in
// src/shared/ItemModels.luau, so the pictures match the game. (Glass covers are left out:
// the renderer can't draw see-through parts.) Uses GameArt.cs.
public static class ExclusiveModels
{
    // A Roblox-style CFrame: a position and a rotation
    public struct CF
    {
        public GameArt.V3 P;
        public GameArt.M3 R;
        public static CF New(double x, double y, double z) { return new CF { P = new GameArt.V3(x, y, z), R = GameArt.M3.Identity }; }
        public static CF Ang(double xDeg, double yDeg, double zDeg) { return new CF { P = new GameArt.V3(0, 0, 0), R = GameArt.M3.Angles(xDeg, yDeg, zDeg) }; }
        public static CF operator *(CF a, CF b) { return new CF { P = a.P + a.R.Apply(b.P), R = a.R.Then(b.R) }; }
    }

    static readonly CF UPRIGHT = CF.Ang(0, 0, 90); // a cylinder standing up
    static readonly CF FORWARD = CF.Ang(0, 90, 0); // a cylinder pointing forward (-Z)
    static readonly Color DARK_METAL = Color.FromArgb(60, 65, 70), BLACK_METAL = Color.FromArgb(35, 37, 42);
    static readonly Color STEEL = Color.FromArgb(185, 190, 200), WOOD = Color.FromArgb(140, 90, 45);
    static readonly Color HAZARD_YELLOW = Color.FromArgb(240, 200, 40), BRASS = Color.FromArgb(215, 175, 70);

    static GameArt.Model m;
    static void Box(string name, double sx, double sy, double sz, CF cf, Color c) { m.Box(cf.P, cf.R, new GameArt.V3(sx, sy, sz), c); }
    static void Cyl(double length, double diameter, CF cf, Color c) { m.Cylinder(cf.P, cf.R, length, diameter, c); }
    static void Ball(double d, CF cf, Color c) { m.Ball(cf.P, d, c); }
    static void Tooth(CF cf, double size, double depth, Color c) { Box("Tooth", size, size, depth, cf * CF.Ang(0, 0, 45), c); }
    static void Glow(bool on) { m.Neon = on; }

    public static GameArt.Model Build(string id)
    {
        m = new GameArt.Model();
        switch (id)
        {
            case "GravityFlipper": GravityFlipper(); break;
            case "FreezeRay": FreezeRay(); break;
            case "AcidBlaster": AcidBlaster(); break;
            case "StormCloud": StormCloud(); break;
            case "BanHammer": BanHammer(); break;
            case "Railgun": Railgun(); break;
            case "Minigun": Minigun(); break;
            case "MissileSwarm": MissileSwarm(); break;
        }
        return m;
    }

    static void GravityFlipper()
    {
        Color purple = Color.FromArgb(170, 70, 255);
        Ball(1.3, CF.New(0, 0, 0), Color.FromArgb(45, 40, 60));
        Glow(true); Ball(0.75, CF.New(0, 0, 0.35), purple); Cyl(0.12, 2.5, FORWARD, purple); Glow(false);
        Cyl(0.12, 2.1, CF.Ang(0, 0, 90), Color.FromArgb(90, 80, 120));
        Glow(true);
        foreach (int side in new[] { 1, -1 })
        {
            Box("Arrow", 0.18, 0.5, 0.18, CF.New(0, side * 1.0, 0.2), Color.White);
            Tooth(CF.New(0, side * 1.3, 0.2) * CF.Ang(0, 0, side > 0 ? 0 : 180), 0.4, 0.18, Color.White);
        }
        Glow(false);
    }

    static void FreezeRay()
    {
        Color ice = Color.FromArgb(120, 220, 255);
        Box("Body", 0.8, 0.8, 1.8, CF.New(0, 0, 0.3), Color.FromArgb(235, 240, 245));
        Glow(true); Cyl(1.1, 0.55, CF.New(0, 0.6, 0.4) * FORWARD, ice); Glow(false);
        Cyl(1.2, 0.4, CF.New(0, 0, -1.1) * FORWARD, Color.FromArgb(150, 160, 175));
        Glow(true);
        foreach (double z in new[] { -0.8, -1.25 }) Cyl(0.12, 0.8, CF.New(0, 0, z) * FORWARD, ice);
        Cyl(0.2, 0.5, CF.New(0, 0, -1.75) * FORWARD, ice);
        Glow(false);
        Box("Grip", 0.3, 0.7, 0.35, CF.New(0, -0.6, 0.8) * CF.Ang(-15, 0, 0), Color.FromArgb(60, 70, 90));
    }

    static void AcidBlaster()
    {
        Color acid = Color.FromArgb(120, 255, 60);
        Box("Body", 0.7, 0.7, 1.7, CF.New(0, -0.1, 0.3), Color.FromArgb(70, 75, 60));
        Glow(true); Cyl(1.2, 0.85, CF.New(0, 0.55, 0.45) * FORWARD, acid); Glow(false);
        Cyl(0.2, 0.95, CF.New(0, 0.55, 0.45) * FORWARD, HAZARD_YELLOW);
        Cyl(1.2, 0.35, CF.New(0, -0.05, -1.0) * FORWARD, DARK_METAL);
        Cyl(0.35, 0.55, CF.New(0, -0.05, -1.7) * FORWARD, BLACK_METAL);
        Glow(true); Ball(0.22, CF.New(0, -0.32, -1.78), acid); Glow(false);
        Box("Grip", 0.3, 0.7, 0.35, CF.New(0, -0.65, 0.85) * CF.Ang(-15, 0, 0), BLACK_METAL);
    }

    static void StormCloud()
    {
        double[,] puffs = { { -2.3, 0.1, 0, 2.4 }, { -0.8, 0.5, 0, 3 }, { 1, 0.4, 0, 2.9 }, { 2.5, 0, 0, 2.2 }, { 0, -0.4, 0.2, 2.6 } };
        for (int i = 0; i < 5; i++)
        {
            Color shade = (i + 1) % 2 == 0 ? Color.FromArgb(95, 100, 115) : Color.FromArgb(120, 125, 140);
            Ball(puffs[i, 3], CF.New(puffs[i, 0], puffs[i, 1], puffs[i, 2]), shade);
        }
        Color yellow = Color.FromArgb(255, 230, 80);
        Glow(true);
        Box("Bolt", 0.2, 0.7, 0.2, CF.New(0.2, -1.4, 0.9) * CF.Ang(0, 0, 25), yellow);
        Box("Bolt", 0.2, 0.6, 0.2, CF.New(0.05, -1.85, 0.9) * CF.Ang(0, 0, -30), yellow);
        Glow(false);
    }

    static void BanHammer()
    {
        Box("Mount", 2.4, 0.5, 2, CF.New(0, 2.25, 0), BLACK_METAL);
        Cyl(0.9, 1, CF.New(0, 1.6, 0) * UPRIGHT, STEEL);
        Cyl(2, 0.45, CF.New(0, 0.3, 0) * UPRIGHT, WOOD);
        Cyl(0.5, 0.55, CF.New(0, -0.55, 0) * UPRIGHT, BLACK_METAL);
        Box("Head", 3.8, 1.6, 1.8, CF.New(0, -1.55, 0), Color.FromArgb(200, 30, 30));
    }

    static void Railgun()
    {
        Color blue = Color.FromArgb(60, 160, 255);
        Box("Body", 0.9, 0.9, 1.4, CF.New(0, 0, 0.8), Color.FromArgb(45, 48, 58));
        Glow(true); Ball(0.5, CF.New(0, 0, 0.1), blue); Glow(false);
        foreach (double y in new[] { 0.32, -0.32 }) Box("Rail", 0.2, 0.18, 2.6, CF.New(0, y, -0.9), STEEL);
        Glow(true);
        foreach (double z in new[] { -0.4, -1.0, -1.6 }) Cyl(0.12, 0.55, CF.New(0, 0, z) * FORWARD, blue);
        Glow(false);
        Box("Grip", 0.3, 0.7, 0.35, CF.New(0, -0.65, 1.1) * CF.Ang(-15, 0, 0), BLACK_METAL);
    }

    static void Minigun()
    {
        Box("Body", 0.9, 0.9, 1.3, CF.New(0, 0, 0.7), DARK_METAL);
        Cyl(0.5, 0.7, FORWARD, BLACK_METAL);
        for (int i = 1; i <= 6; i++)
            Cyl(2, 0.16, CF.Ang(0, 0, i * 60) * CF.New(0, 0.22, -1.2) * FORWARD, BLACK_METAL);
        foreach (double z in new[] { -0.5, -2.05 }) Cyl(0.15, 0.7, CF.New(0, 0, z) * FORWARD, DARK_METAL);
        Box("Ammo", 0.7, 0.8, 0.9, CF.New(0.65, -0.35, 0.7), Color.FromArgb(90, 100, 60));
        for (int i = 0; i <= 4; i++) Box("Cartridge", 0.12, 0.12, 0.28, CF.New(0.4, -0.05 + i * 0.05, 0.5 - i * 0.18), BRASS);
        Box("Handle", 0.15, 0.6, 0.15, CF.New(0, 0.65, 0.7), BLACK_METAL);
        Box("Grip", 0.3, 0.75, 0.35, CF.New(0, -0.7, 1.1), BLACK_METAL);
    }

    static void MissileSwarm()
    {
        Color olive = Color.FromArgb(80, 95, 60);
        Box("Pod", 1.6, 1.6, 2.2, CF.New(0, 0, 0.1), olive);
        Box("Stripe", 1.62, 0.25, 2.22, CF.New(0, 0.45, 0.1), HAZARD_YELLOW);
        foreach (double x in new[] { -0.4, 0.4 })
            foreach (double y in new[] { -0.4, 0.4 })
            {
                Cyl(0.3, 0.62, CF.New(x, y, -1.0) * FORWARD, BLACK_METAL);
                Ball(0.4, CF.New(x, y, -1.1), Color.FromArgb(200, 40, 40));
            }
        Box("Sight", 0.2, 0.35, 0.5, CF.New(0, 0.95, 0.3), DARK_METAL);
        Box("Grip", 0.35, 0.8, 0.4, CF.New(0, -1.1, 0.5), DARK_METAL);
    }
}
