# F150RR — Ford F-150 Raptor R (BeamNG.drive)

Realistic Ford **F-150 Raptor** pickup for BeamNG.drive. Vehicle folder: `vehicles/f150`. Author: **The_Gamer6000**.

Unpack / clone this repo as folder **`F150RR`**.

## About

Crew-cab Raptor with custom jbeam (frame, body, suspension, drivetrain), Ford-style **Trail Control** UI (`fordControl`), and **AdvanceTrac / DSE** drive modes. Stock Raptor configs use the F150 RR supercharger with the 10-speed SelectShift; Normal / Street-style configs stay naturally aspirated.

## Features

- **10 configs** under `vehicles/f150/`: Normal, Blacked Out, Raptor, Blacked Out Raptor, Monster, Monster Blacked Out, Baja, Sport, Tow, Police
- Drive-mode packs via DSE (street / SC Raptor / Baja / Tow packs)
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

3. **Meshes:** body / door / interior flexbodies use `sdd_trx2_*` meshes from the in-repo pack:

   ```
   vehicles/f150/textures/trx2.cached.dts
   ```

   That file ships with this repo — no separate mesh download is required for the body to spawn. A draft GitHub Release may mention `RaptR.cached.dts` / `F150RR-meshes.zip`, but that pack is currently empty and is **not** required.

4. Enable the mod in Mods if needed, then spawn **Ford F-150 Raptor**.

## Credits

- **The_Gamer6000** — vehicle author (`info.json` / jbeam / fordControl)
- **Diamondback** — Driving & Safety Electronics (DSE) jbeam (`f150_dse*.jbeam`)
- **Redknee** — Hellcat engine/exhaust sound samples under `art/sound`
- **Royal Renderings** — Raptor R crew-cab body, frame mesh, and materials (`trx2.cached.dts`)
- Ford names and marks belong to their respective owners; this is a fan mod for BeamNG.drive
