# Publishing Loadout Pilot 1.0.0

## 1. GitHub

Create an empty public repository named `LoadoutPilot`.

Extract the GitHub package and copy the contents of the `LoadoutPilot-v1.0.0` folder into the repository root.

Then run:

```bash
git init
git add .
git commit -m "Release Loadout Pilot 1.0.0"
git branch -M main
git remote add origin YOUR_GITHUB_REPOSITORY_URL
git push -u origin main
```

After the repository is online, create and push the stable tag:

```bash
git tag -a v1.0.0 -m "Loadout Pilot 1.0.0"
git push origin v1.0.0
```

The included GitHub Actions workflow validates and packages tagged releases.

## 2. CurseForge project

Create a World of Warcraft Addons project named **Loadout Pilot**.

Use:

- Summary from `CURSEFORGE_SUBMISSION.md`
- Description from `CURSEFORGE_DESCRIPTION.md`
- MIT license
- Retail / Midnight 12.1.0
- `branding/LoadoutPilot_Logo_512.png` as the project logo

Upload `LoadoutPilot-v1.0.0-CurseForge.zip` as a **Release** file.

## 3. Connect automated CurseForge releases

After CurseForge approves the project, copy its numeric project ID and add this line to `LoadoutPilot.toc`:

```text
## X-Curse-Project-ID: YOUR_PROJECT_ID
```

Then create a CurseForge API token and add it to GitHub repository secrets as:

```text
CF_API_TOKEN
```

The existing workflow passes the token to BigWigsMods/packager for tagged releases.

## 4. Public support link

The README, CurseForge description, release notes, and support page all contain:

https://buymeacoffee.com/bertuzzi

## 5. Final verification before upload

- Confirm the addon folder is named `LoadoutPilot`.
- Confirm `LoadoutPilot.toc` reports version `1.0.0` and Interface `120100`.
- Confirm no Lua errors on login.
- Confirm World mapping loads.
- Confirm Delve, Dungeon, Mythic+, Raid, and PvP detection.
- Confirm PvP -> World restores both talents and equipment.
- Confirm the HUD leaves `Applying...` after the transition.
- Confirm minimap button sits on the outer rim and persists after `/reload`.
- Confirm PT-BR and English language selection.
- Confirm chat messages can be disabled.
