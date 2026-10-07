# Publishing Loadout Pilot 2.2.0

The runtime is the same build approved after in-game user testing on October 7, 2026.

## CurseForge

Upload `LoadoutPilot-v2.2.0-CurseForge.zip` as **Release**. Use `RELEASE_NOTES_v2.2.0.md` as the changelog. The ZIP has one top-level `LoadoutPilot` directory.

## Source

The source archive includes validation scripts, mocked API tests, documentation and packaging workflows. Suggested tag: `v2.2.0`.

## Validation

```bash
python3 scripts/validate.py
texlua tests/smoke.lua .
```

See `VALIDATION_REPORT.md` for local checks and the live-test approval, and `TESTING.md` for the regression checklist.
