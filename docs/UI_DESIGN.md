# Workshop UI design

The viewer follows the Vault daylight glass style shared by `vault_dance` and
`vault_crypto`: a pale slate canvas, frosted sidebar and toolbar, one dark ink
hero, glass panels, restrained blue accents and compact typography. It remains
an Express-served static UI under `frontend/public/`.

Hanken Grotesk and JetBrains Mono variable Latin fonts are served locally.
The vendored files come from Fontsource packages version 5.3.0; their SIL Open
Font License notices accompany them in `frontend/public/fonts/`. No external
font or image service is required. The workshop mark is a local SVG.

Desktop section links navigate within the single page. Below 900px the rail
is hidden; all sections remain in document order. At phone widths the status
facts stack and API controls wrap. Tables scroll within their own frame.
Keyboard focus indicators, a skip link, labelled sections, live status and
native expandable health details support keyboard and screen reader use.

Status retains its authorization meaning:

| State | Appearance | Meaning |
| --- | --- | --- |
| Vault unlocked | Green | Backend reports both authorized and DB ready |
| Baseline connected | Amber | Environment credentials work; Vault checkpoint incomplete |
| Locked, denied or unavailable | Red | Data is withheld and old rows/reveal are cleared |
| Checking | Neutral | Readiness check in progress |

Identity chips describe the three workshop personas. They do not switch the
application identity or imply that a persona has authenticated. UI styling
adds no authentication path and preserves the backend's unlock decision.

Use `make build`, apply the explicit solution profile, then run
`make test-browser` to check the real unlock and intercepted failure states.
Inspect `.workshop/viewer-desktop.png` and `viewer-mobile.png` after layout
changes. Restore `PROFILE=starter` when leaving the learner lab running.
