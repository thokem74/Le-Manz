# Le Manz

A complete offline Android racing game made with **Godot 4.7.2**, inspired by
Commodore/HAL Laboratory's 1982 *Le Mans*. Pixel graphics, lettering, and arcade
effects are recreated for this project; no original ROM, sprites, or recordings
are needed. There is no background music.

## Play

Open `project.godot` in Godot and press **F5**. On Android, install
`builds/android/le-manz-debug.apk` and open **Le Manz** from the launcher.

- Play in **portrait**. Hold the **left half** to steer left or the **right half**
  to steer right. Release stops ordinary-road steering without lane snapping.
- A **quick tap (160 ms or less)** completes one lane-width displacement from
  where the press began. Completion takes **0.18 seconds after release**. One
  additional tap can queue; holding cancels automated tap movement.
- Forward speed is always **180 km/h**. Sideways speed is **180 logical pixels/s**.
- On ice, held steering accelerates gradually, then coasts briefly after release.
  Countersteer to brake or reverse the slide. A full-speed release drifts about
  **27 pixels over 0.30 seconds**. Ice taps settle precisely over **0.30 seconds**.
- Opposite simultaneous touches cancel steering; overlapping touches never
  trigger lane taps. Each touch keeps its starting direction when dragged.
- On desktop, use held **Left/Right**, **A/D**, or the mouse. Quick key presses
  and clicks also complete a lane displacement. **P/Escape** pauses; Android
  **Back** pauses during a race and returns from menus.
- Distance earns **2 points/metre**. Every **10 clean passes** earns **1,000 points**.
  Every **20,000 points** awards more time.
- A crash resets the current clean streak, plays a crash effect, and vibrates
  the device if enabled. Automatic pit recovery costs **4 seconds** while the
  clock continues; distance scoring stops. Re-entry is protected for **1 second**.
- Roads cycle through open road, curves, a narrow motorway, ice, and night.
  Narrow sections use the middle two marked lanes and smoothly constrain the car;
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
- `PlayerCar`: continuous steering, per-control press timing, ice momentum, and
  one queued tap; `RaceRoad`: shared lane
  geometry, road variants, and scrolling. `RoadStrip` caches its visual nodes.
- `RaceTraffic` / `TrafficCar`: 24 reusable cars, spacing, indicators,
  overtakes, and forgiving collision bounds. Narrow-road traffic has equal
  relative speeds and at least a 60-pixel gap so it cannot form a traffic wall.
- `GameProfile` / `RaceAudio`: local persistence and audio; `game.gd` coordinates
  race phases and the existing UI nodes.

Rendering uses Compatibility mode and a **280 × 480** base logical canvas with
nearest-neighbour filtering and aspect-preserving scaling. Tall phones extend the
road vertically; portrait tablets centre the 280-pixel road horizontally. The
64-pixel dashboard sits above the road. Menus, dashboard, steering hints, and pit
position respect the Android display safe area. The player stays 80 logical
pixels above the playfield bottom. The pre-authored road-strip pool covers up to
1,280 logical pixels of road; strips outside the playfield are hidden. No network
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
portrait-only orientation, immersive mode, and the vibration permission.

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
continuous steering, quick taps, ice momentum, road boundaries and narrowing,
multi-touch event handling, pit recovery,
expiry, restart, background notifications, Android Back, traffic spacing,
and complete races. It uses isolated `/tmp` profiles rather than your game saves.
The rendering script captures real scene layouts; views include `title`, `help`,
`settings`, `pause`, `results`, `countdown`, `road`, `curves`, `narrow`, `ice`, and `night`.

Validation on **10 October 2026**:

- 230 integration checks passed, including complete races on all three levels,
  timer bonuses, records, releases over UI, cancelled touches, and pause/restart.
- Rendered and inspected menus, countdown, and every road variant at approximately
  **9:16**, **9:20**, and **3:4** using actual offscreen Godot scene rendering.
  Add `--size=280x622` or `--size=360x480` to the capture command for these sizes.
- Debug APK export and signature verification passed. The APK manifest requires
  portrait orientation, ARM64, and the vibration permission.
- Installed and exercised on a **Samsung SM-A176B (1080 × 2340)**. The top HUD
  clears the camera cutout. Touch menus, held steering between lanes, quick-tap
  lane displacement, ice hold/release drift, pause, restart, and explicit resume
  after background verified.
- Android vibration history confirms completed **250 ms** crash requests.
- Deterministic collision-free simulation reaches the first time bonus at about
  **85.5 seconds** on each difficulty. Stationary drivers finish at their expected
  180/120/90-second clocks. These checks measure scoring opportunity and lifecycle;
  they do not substitute for human balance testing.

Subjective audio listening, measured frame pacing, long human difficulty
playtests, physical simultaneous multi-touch, and subjective ice feel remain
unverified. Ice acceleration,
drift, countersteering, and precise tap completion are covered by automated tests.
The device run produced no Godot script or audio errors. Additional devices remain
useful for performance, cutout, and compatibility feedback.

## References

- [C64-Wiki: Le Mans](https://www.c64-wiki.com/wiki/Le_Mans)
- [C64 Online: Le Mans](https://c64online.com/c64-games/le-mans/)
- [Three Fields Entertainment: Le Mans history](https://www.threefieldsentertainment.com/2018/12/07/le-man-commodore-64/)
