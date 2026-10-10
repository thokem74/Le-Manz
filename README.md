# Le Manz

A complete offline Android racing game made with **Godot 4.7.2**, inspired by
Commodore/HAL Laboratory's 1982 *Le Mans*. Pixel graphics, lettering, and arcade
effects are recreated for this project; no original ROM, sprites, or recordings
are needed. There is no background music.

## Play

Open `project.godot` in Godot and press **F5**. On Android, install
`builds/android/le-manz-debug.apk` and open **Le Manz** from the launcher.

- Tap the **left half** of the screen to move one lane left, or the **right half**
  to move one lane right. Each press moves once; holding and dragging do not repeat.
- Forward speed is always **180 km/h**. Lane changes take **0.18 seconds**, with
  at most one additional tap buffered during a move.
- On desktop, use **Left/Right**, **A/D**, or mouse clicks. **P/Escape** pauses;
  Android **Back** pauses during a race and returns from menus.
- Distance earns **2 points/metre**. Every **10 clean passes** earns **1,000 points**.
  Every **20,000 points** awards more time.
- A crash resets the current clean streak, plays a crash effect, and vibrates
  the device if enabled. Automatic pit recovery costs **4 seconds** while the
  clock continues; distance scoring stops. Re-entry is protected for **1 second**.
- Roads cycle through open road, curves, a narrow motorway, ice, and night.
  Narrow sections use the middle two lanes. Ice keeps steering predictable;
  headlights and rear lights help with night driving.
- Backgrounding freezes the race and audio. Returning requires **Resume Race**.

| Difficulty | Starting clock | Extra time per 20,000 points |
|---|---:|---:|
| Easy | 180 seconds | 90 seconds |
| Normal | 120 seconds | 60 seconds |
| Hard | 90 seconds | 45 seconds |

Difficulty changes only the clock. Each level has its own local high score.
The selected difficulty, sound setting, vibration setting, and records are saved
in `user://profile.cfg`. Records are updated when a race finishes or is ended
from the pause menu. The timer values are mobile adaptation values, not a claim
of exact original timings.

## Develop and tune

The main scene is `scenes/game.tscn`. Cars, road strips, traffic pool, audio
players, menus, and HUD are all visible in the Godot editor. Scripts control
their behavior rather than constructing their visuals at runtime.

- `resources/race_settings.tres`: select this resource in the Inspector to tune
  difficulty clocks, speed, steering, repairs, scoring, and traffic intervals.
  Clock-array order is **Easy, Normal, Hard**.
- `RaceSession`: distance, clean-pass bonuses, timer thresholds, and race totals.
- `PlayerCar`: lane movement and one buffered input; `RaceRoad`: shared lane
  geometry, road variants, and scrolling. `RoadStrip` caches its visual nodes.
- `RaceTraffic` / `TrafficCar`: twelve reusable cars, spacing, indicators,
  overtakes, and forgiving collision bounds. Narrow-road traffic has equal
  relative speeds and at least a 60-pixel gap so it cannot form a traffic wall.
- `GameProfile` / `RaceAudio`: local persistence and audio; `game.gd` coordinates
  race phases and the existing UI nodes.

Rendering uses Compatibility mode and a **384 × 240** logical canvas with
nearest-neighbour filtering and aspect-preserving letterboxing. The Android
pause button is also constrained to the reported display safe area. No network
permission, account, advertising, or server is required.

The Python 3 standard-library tools are optional: `tools/generate_assets.py`
recreates the hand-designed SVG sprites, bitmap font, and synthesized WAVs;
`tools/generate_scenes.py` recreates the initial scene/theme layouts.
**Regenerating scenes overwrites manual edits to those scenes and the theme.**
Ordinary game development can use the Godot editor directly without these tools.

## Build Android

Install matching Godot 4.7.2 export templates, OpenJDK 17, and an Android SDK.
Set the SDK/JDK paths in **Editor Settings → Export → Android** as described in
the [Godot Android export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).
The checked-in **Android** preset targets ARM64 devices, Android 7.0 or later,
landscape orientation, immersive mode, and the vibration permission.

```sh
mkdir -p builds/android
godot --headless --editor --path . --import --quit
godot --headless --path . --export-debug Android builds/android/le-manz-debug.apk
adb install -r builds/android/le-manz-debug.apk
```

Godot 4.7's Android template uses a launcher alias. To start through ADB:

```sh
adb shell am start -n org.lemanz.arcade/com.godot.game.GodotAppLauncher
```

Builds and keystores are ignored by Git. The delivered APK is debug-signed;
store release signing and publishing require a separate release setup.

## Verification

```sh
godot --headless --path . --script tests/run_tests.gd
godot --path . --script tests/capture.gd -- --view=night --out=/tmp/le-manz-night.png
```

The integration suite covers difficulty clocks/bonuses, scoring, persistence,
lane boundaries and buffering, multi-touch event handling, pit recovery,
expiry, restart, background notifications, Android Back, traffic spacing,
and complete races. It uses isolated `/tmp` profiles rather than your game saves.
The rendering script captures real scene layouts; views include `title`, `help`,
`settings`, `pause`, `results`, `road`, `curves`, `narrow`, `ice`, and `night`.

Validation on **10 October 2026**:

- 117 integration checks passed with no script errors or shutdown leaks.
- Godot scene import, debug APK export, and APK signature verification passed.
- Desktop layouts inspected for title, instructions, settings, results, and road
  variants; wide landscape letterboxing inspected on Android at 2340 × 1080.
- Installed and exercised on a **Samsung SM-A176B**: touch menus, exactly one
  lane per left/right tap, Android Back pause, explicit resume after background,
  automatic pit recovery, and saved difficulty/records verified.
- Android's vibration history recorded completed **250 ms** crash pulses from
  the game, matching the configured haptic request.
- Deterministic collision-free traffic simulation reached the first extra-time
  bonus at approximately **83 seconds** on every difficulty. Stationary drivers
  completed races on all three levels. This checks pacing opportunity; it does
  not substitute for human difficulty playtesting.

Measured GPU frame pacing and subjective audio listening were not verified.
Long play sessions across additional Android devices remain useful for balance
and compatibility feedback. Engine, crash, and bonus WAVs are generated and
imported, and the device run produced no game audio/script errors.

## References

- [C64-Wiki: Le Mans](https://www.c64-wiki.com/wiki/Le_Mans)
- [C64 Online: Le Mans](https://c64online.com/c64-games/le-mans/)
- [Three Fields Entertainment: Le Mans history](https://www.threefieldsentertainment.com/2018/12/07/le-man-commodore-64/)
