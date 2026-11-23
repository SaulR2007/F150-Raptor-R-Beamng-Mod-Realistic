# F150RR — Ford F-150 Raptor R (BeamNG.drive)

Realistic Ford **F-150 Raptor** pickup for BeamNG.drive. Vehicle folder: `vehicles/f150`. Author: **The_Gamer6000**.

Unpack / clone this repo as folder **`F150RR`**.

## About

Crew-cab Raptor with custom jbeam (frame, body, suspension, drivetrain), Ford-style **Trail Control** UI (`fordControl`), and **AdvanceTrac / DSE** drive modes. The Raptor config uses the F150 RR supercharger with the 10-speed SelectShift; Normal stays naturally aspirated; Monster uses the dedicated Monster Supercharger.

## Features

- **3 configs** under `vehicles/f150/`: **F-150 Normal** (base f150), **F-150 Raptor**, **F-150 Monster**
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

3. **Install the mesh zip** (too large for normal git pushes and auto extraction):

   - Open **`F150RR-meshes.zip`** in the F150RR Main Folder
   - Extract the **`Vehicles`** folder into the main F150RR Folder so this file exists:

     ```
     vehicles/f150/textures/RaptR.cached.dts
     ```

   Body / door / interior flexbodies reference `sdd_raptR_*` meshes from that pack. Chassis / suspension / tire / wheel meshes still use in-repo `vehicles/f150/textures/trx2.cached.dts`. Without `RaptR.cached.dts` the truck spawns with a broken/missing body.

4. Enable the mod in Mods if needed, then spawn **Ford F-150 Raptor** and add the Custom **Ford Control** UI App.

## Credits

- **The_Gamer6000** — vehicle author (`info.json` / jbeam / fordControl)
- **Diamondback** — Driving & Safety Electronics (DSE) jbeam (`f150_dse*.jbeam`)
- **Redknee** — Hellcat engine/exhaust sound samples under `art/sound`
- **Royal Renderings** — Raptor R crew-cab body, frame mesh, and materials (`RaptR.cached.dts`)
- Ford names and marks belong to their respective owners; this is a fan mod for BeamNG.drive
