# MeggicBuffTracker

**MeggicBuffTracker** is a lightweight World of Warcraft (TurtleWoW) addon for tracking your buffs, weapon enchants, and consumables in an easy-to-read frame.

## Features

- Track up to 40 buffs, spells, items, or weapon enchants.
- Visual alerts when buffs are missing or about to expire (glowing red row).
- Click to cast spells or use items directly from the tracker if they're expired or <2min remaining.
- Shift+Click to remove tracked buffs.
- Configurable UI with drag-and-drop positioning.
- Shows item counter on hover for items and spells requiring reagents.

## Installation

1. Download or clone this repository.
2. Place the folder in your `World of Warcraft\_retail_\Interface\AddOns\` directory.
3. Log in to WoW and ensure the addon is enabled on the character screen.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/mbt` | Toggle the tracker frame visibility |
| `/mbt config` | Open the configuration window to add new buffs |
| `/mbt reset` | Reset tracker position to center of screen |
| `/mbt clear` | Remove all tracked buffs |
| `/mbt help` | Show usage instructions in chat |

## How to Add Custom Buffs

1. Type `/mbt config` (or click the "(C)" in the top-right of the mbt window to open the configuration window.
2. Click **Refresh Buffs** to populate your current buffs.
3. Click a buff icon to select it. The **Buff / Spell / Item** field auto-fills.
4. Edit the name if needed (must exactly match).  
5. Choose the **Action Type**: Spell or Item.
6. Set the **Duration** in minutes (decimals is fine).  
7. Click **Add Custom Buff** to track it.

## How to Add Template-d Buffs

1. Type `/mbt config` (or click the "(C)" in the top-right of the mbt window to open the configuration window.
2. Select your desired spec from the drop-down menu.
3. Click "Add"
4. All relevant buffs will populate in the tracker.
5. Remove the ones you don't want to track.

**Weapon Enchants:**  
Click the “Select Current Weapon Enchant” button once your weapon has the desired enchant.

## Using the Tracker

- Click a buff row to cast/use it (if action defined).  
- Shift+Click a buff row to remove it.
- Drag and drop to re-order the rows.
- Missing buffs are highlighted with a red glow.  
- Remaining time is color-coded:
  - Green: healthy
  - Yellow: <5 minutes
  - Red: <1 minute or missing

## Notes

- Buffs must match the **exact name** for automatic tracking.  
- Settings and tracked buffs are saved automatically per character.  
- The tracker frame is draggable; position is remembered across sessions.

## Known Issues
- The 'remaining time' will be incorrect if relogging and will also refresh if you do /reload. Directly getting the ACTUAL remaining time doesn't seem possible with current API. This is not a huge issue as I just needed it to let me know when the buff expires - how much it has left isn't too big of an issue.
- If the addon loads and you can't see the mbt window, do "/mbt reset" to put it back to the middle of your screen (it can go off-screen)
- Weapon enchants likely won't work with off-hand weapons. I haven't tried it as I don't have a rogue/offhand class.
- If you find any other bugs please let me know!
