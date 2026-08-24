# Publishing Loadout Pilot 1.1.1

## Recommended flow

1. Install `LoadoutPilot-v1.1.1-Test.zip` locally.
2. Complete the specialization and dungeon-override checks in `TESTING.md`.
3. If the live tests pass, commit the GitHub source and tag `v1.1.1`.
4. Upload `LoadoutPilot-v1.1.1-CurseForge.zip` as a Release (or Beta while doing wider community testing).

## GitHub

From the repository root:

```bash
git add .
git commit -m "Release Loadout Pilot 1.1.1"
git tag -a v1.1.1 -m "Loadout Pilot 1.1.1"
git push origin main
git push origin v1.1.1
```

The included GitHub Actions workflow validates and packages tagged releases.

## CurseForge automation

If the project has a numeric CurseForge project ID, add it to `LoadoutPilot.toc` as:

```text
## X-Curse-Project-ID: YOUR_PROJECT_ID
```

Add the CurseForge API token to GitHub repository secrets as `CF_API_TOKEN`.

## Public support link

The README, CurseForge description, release notes, and support page contain:

https://buymeacoffee.com/bertuzzi

## Final verification before upload

- Version is `1.1.1`, Interface is `120100`.
- Existing 1.0 mappings migrate without loss.
- General specialization mapping works.
- Dungeon override can change specialization and talent loadout.
- Role protection blocks cross-role specialization changes in grouped content when incompatible with the protected role.
- Same-role switches such as DPS -> DPS remain automatic.
- An override can inherit the base equipment mapping.
- Moving to another dungeon restores its override or the Mythic+ default.
- Specialization changes queue safely during combat.
- PvP -> World still restores talents and equipment.
- HUD leaves `Applying...` after successful transitions.
- Minimap button remains on the outer rim.
- PT-BR / English selector and chat-message option still work.
