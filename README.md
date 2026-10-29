# F150RR — Ford F-150 Raptor R (BeamNG.drive)

Realistic Ford **F-150 Raptor** pickup for BeamNG.drive. Vehicle folder: `vehicles/f150`. Author: **The_Gamer6000**.

Unpack / clone this repo as folder **`F150RR`**.

## About

Crew-cab Raptor with custom jbeam (frame, body, suspension, drivetrain), Ford-style **Trail Control** UI (`fordControl`), and **AdvanceTrac / DSE** drive modes. Powertrain is a supercharged 6.2L V8 with 10-speed SelectShift (limited and unlocked configs).

## Features

- **18 configs** under `vehicles/f150/`: Raptor, Raptor Unlocked / Black / Code Orange, Baja (+ Unlocked), Rock Crawl, Sand Runner, Off-Road Pack, Street, Sport Unlocked, Stealth, Police, Family Tow, Gooseneck Tow, Heavy Haul Unlocked, Trailer Loading, Work White
- Drive-mode packs via DSE: Normal / Sport / Slippery, Off-Road / Sand / Baja / Rock Crawl, Tow/Haul
- In-game **fordControl** app — 4x4 pad, lockers, trail camera, Trail Control
- Custom suspension, differentials, wheels/tires, and cabin screen assets
- Hellcat-based engine/exhaust sound bank (`art/sound`)

## Install

1. Clone or download this repo.
2. Place the **repo root** (so `vehicles/`, `lua/`, `ui/`, `scripts/`, `art/` sit at the top) into BeamNG’s unpacked mods folder as **`F150RR`**:

   ```
   %LOCALAPPDATA%\BeamNG\BeamNG.drive\<version>\mods\unpacked\F150RR\
   ```

   Example:

   ```
   C:\Users\<you>\AppData\Local\BeamNG\BeamNG.drive\current\mods\unpacked\F150RR\
   ```

   That folder should contain `vehicles/`, `lua/`, `ui/`, `art/`, `scripts/`, and this `README.md` directly — not nested inside another folder.

3. **Download the mesh pack** from the latest [GitHub Release](https://github.com/SaulR2007/F150-Raptor-R-Beamng-Mod-Realistic/releases) (`F150RR-meshes.zip`). Extract it so these files exist:

   ```
   vehicles/f150/textures/RaptR.cached.dts
   ```

   (`RaptR.cached.dts` is ~129 MB, so it cannot live in the git repo. Without it the Raptor body meshes are missing.)

4. Enable the mod in Mods if needed, then spawn **Ford F-150 Raptor**.

## Credits

- **The_Gamer6000** — vehicle author (`info.json` / jbeam / fordControl)
- **Diamondback** — Driving & Safety Electronics (DSE) jbeam (`f150_dse*.jbeam`)
- **Redknee** — Hellcat engine/exhaust sound samples under `art/sound`
- **Royal Renderings** — Raptor R crew-cab body, frame mesh, and materials (`RaptR.cached.dts`)
- Ford names and marks belong to their respective owners; this is a fan mod for BeamNG.drive
