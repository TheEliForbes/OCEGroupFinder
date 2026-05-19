# GroupLatencyFinder

A World of Warcraft addon that visually identifies premade group listings in the **Group Finder** (LFG List) that are led by players on **non-NA realms** for ping purposes.

Disclaimer: Claude coded the base of this, but I made sure to get my grubby mits in there and fix it how I wanted. (Take this however you will)

---

## Features

- **Purple `[FAR]` badge** on every Group Finder result card whose leader is from an OCE/BR realm
- Slash commands to list all tracked realms

---

## Installation

1. Download or clone this repository.
2. Copy the `GroupLatencyFinder` folder into:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
3. Launch (or reload) the game and enable the addon in the **AddOns** menu on the character select screen.

---

## Tracked OCE/BR Realms

| Realm |
|-------|
| Barthilas |
| Caelestrasz |
| Dath'Remar |
| Dreadmaul |
| Frostmourne |
| Gundrak |
| Jubei'Thos |
| Khaz'goroth |
| Nagrand |
| Saurfang |
| Thaurissan |
| Azralon |
| Gallywix |
| Goldrinn |
| Nemesis |
| Tol Barad |
---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/glf` | Show help |
| `/glf realms` | Print all tracked OCE realms to chat |

---

## How It Works

The addon hooks into the **LFG List** UI:

1. **`C_LFGList.GetSearchResultInfo(resultID)`** is called for every visible result card.
2. The `leaderName` field (formatted as `"Name-Realm"`) is parsed to extract the realm.
3. The realm is checked against the known OCE realm list.
4. Matching cards receive a cyan `[OCE]` label, a coloured left border, and an enriched tooltip.

The hooks fire on `LFG_LIST_SEARCH_RESULTS_RECEIVED` and `LFG_LIST_AVAILABILITY_UPDATE`, so the UI updates automatically as you search or filter.

---

## Compatibility

- **Retail WoW** (Interface 12.0.5 / Midnight)
- No dependencies

---

## Contributing

PRs welcome! If Blizzard adds new OCE/BR realms or renames existing ones, just update the `FAR_REALMS` table at the top of `GroupLatencyFinder.lua`.

---

## License

MIT
