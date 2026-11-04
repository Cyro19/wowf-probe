# WoWF Probe

Launch-day capability probe for **World of Warcraft: Forever** (`wowf`, Interface `16001`, Lua 5.1).

Forever runs the modern Mainline UI engine with the Midnight restriction stack (secret values, restricted combat log). During the beta, several behaviors changed build-to-build. This addon settles them on whatever build is in front of you.

## What it probes

| Probe | Question answered |
|---|---|
| build | `GetBuildInfo()` — is the TOC interface still 16001? |
| project-id | `WOW_PROJECT_ID` vs `WOW_PROJECT_CAMELOT` (18) |
| secret-api | `issecretvalue` / `canaccessvalue` / `issecrettable` / `canaccesstable` present |
| secret-health | Is `UnitHealth("player")` secret right now? Arithmetic/comparison blocked? |
| combatlog | `C_CombatLog.IsCombatLogRestricted()` state; does registering `COMBAT_LOG_EVENT_UNFILTERED` throw? |
| secure-handlers | `SecureHandlerWrapScript` / `RegisterStateDriver` available (snippet compile broke on beta 69913) |
| forever-gamerules | `C_GameRules.GetForeverExperiencePreset()` present and its value |
| platform | `C_Timer`, addon compartment, Settings API, `C_CurveUtil`, `C_DurationUtil`, `C_RestrictedActions`, `GetCurrentRegion` |
| auras | `C_UnitAuras.GetAuraDataByIndex` present |
| savedvars | `bootCount` increments across `/reload` — SavedVariables persistence works (broke mid-beta, fixed ~70009) |

## Install

- **WowUp / WowUp.CF**: Get Addons → Install from URL → `https://github.com/Cyro19/wowf-probe`
- **Manual**: download the latest release zip, extract so the path is `World of Warcraft\_forever_\Interface\AddOns\WoWFProbe\WoWFProbe.toc`, restart the client.

## Use

```
/wowfprobe
```

Results print to chat and are stored in `WoWFProbeDB.lastReport` (SavedVariables) for copy/paste. Run it, `/reload`, run again: `savedvars bootCount` must increment.

To probe under forced combat restrictions (session-only CVar):

```
/run SetCVar('addonCombatRestrictionsForced','1')
```

then `/wowfprobe` again and compare.

## Development

- Target: Forever 1.60.1+, Mainline API family (12.1.5), **not** Classic Era.
- Releases are automated: bump `## Version:` in `WoWFProbe.toc` and push to `main`; the release workflow tags `v<version>` and attaches `WoWFProbe.zip`.
