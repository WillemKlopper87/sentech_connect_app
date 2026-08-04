# Sentech Brand Tokens (extracted from Sentech CI Manual 2025)

Source: `Sentech CI Manual 2025_eMail.pdf`. Distilled for use in `app/theme/` (Material 3 ColorScheme + TextTheme). The CI manual is print/brand-focused and has no digital dark-mode section — the dark theme below is derived from patterns the manual already uses repeatedly (dark navy backgrounds + reversed white logo), not invented from scratch.

## Colours

### Primary
| Name | Hex | Pantone | Notes |
|---|---|---|---|
| SENTECH Blue | `#005BAA` | Reflex Blue | Dominant brand colour, used wherever colour permits |
| Dark Grey | `#6D6E71` | Process Black 70% | Preferred colour for body copy |
| Light Grey | `#BCBEC0` | Process Black 30% | |

### Secondary (accent set)
| Name | Hex | Pantone | Notes |
|---|---|---|---|
| Dark Blue | `#00335C` | 540c | Used as the brand's own dark background colour throughout stationery/brand-application pages — this is the dark-mode surface colour, not a generic black |
| Orange | `#FAA61A` | 123c | |
| Lime Green | `#8EAF3F` | 376c | |
| Light Blue | `#00ACC6` | 2995c | Used as an accent on dark backgrounds in the manual — best contrast choice for a dark-mode primary |
| Red | `#ED1C24`* | 186c | *CI manual lists hex `ed1c24` but RGB `197,19,21` in the same table — these don't match (ed1c24 = 237,28,36). Flagged for confirmation with Sentech marketing before use; hex value used here. |

Tint scale: manual specifies 80/60/40/20/10% tints of every colour above for use as secondary/supporting shades.

## Typography
- **Primary (headings/subheadings):** Avenir Next — weights Ultra Light, Regular, Medium, Semi Bold, Bold, Black. Used in all design materials, marketing, external advertising, web.
- **Secondary (internal docs only):** Figtree (Google Font) — PowerPoint, internal email.
- **System fallback:** Arial — used only on internal documents/communication when Avenir Next isn't installed; letterhead/email body copy.
- **Type hierarchy:** H1 44pt Avenir Next Heavy, H2 38pt Bold, H3 24pt Medium, H4 14pt Regular, H5 12pt Light uppercase.

Flutter mapping: use Avenir Next (licensed) or Figtree (free, Google Fonts package) as `fontFamily` depending on licensing; Arial as the fallback `fontFamilyFallback`.

## Logo rules relevant to theming
- Full-colour logo is only ever placed on a **white** background.
- On any other background, the logo must be the **reversed all-white lockup** — this is the version to bundle for dark mode, not a scaled/recoloured version of the full-colour logo.
- Other than white/black, the logo may only sit on a **100% secondary colour** background (blue, orange, lime, light blue, red) — never a gradient, tint, or arbitrary colour.
- Clear space around the logo = 1× the icon height on all sides, non-negotiable.
- Never stretch, recolor, rearrange, or add effects (drop shadows, etc.) to the logo.

## Theme mapping (proposed)

**Light theme**
- `background` / `surface`: white
- `primary`: `#005BAA` (SENTECH Blue)
- `onSurface` (body text): `#6D6E71` (Dark Grey)
- Logo: full-colour lockup

**Dark theme**
- `background` / `surface`: `#00335C` (Dark Blue) — matches the manual's own dark-page treatment, not an invented near-black
- `primary`: `#00ACC6` (Light Blue) — better contrast against `#00335C` than the darker Reflex Blue, and already used as a dark-background accent in the manual
- `onSurface` (body text): white / `#BCBEC0` for secondary text
- Logo: reversed all-white lockup only

Accent colours (orange, lime, red) carry over unchanged in both themes for status/semantic use (e.g. alerts, badges), consistent with their use in the manual's internal-communique templates.
