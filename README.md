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
- A short press moves a short distance. Movement lasts only while the control is
  held; releasing never completes a lane switch or queues another movement.
- Forward speed is always **180 km/h**. Sideways speed is **180 logical pixels/s**.
- On ice, held steering accelerates gradually, then coasts briefly after release.
  Countersteer to brake or reverse the slide. A full-speed release drifts about
  **27 pixels over 0.30 seconds**. Short presses produce proportionately less drift.
- Opposite simultaneous touches cancel steering. Each touch keeps its starting
  direction when dragged.
- On desktop, use held **Left/Right**, **A/D**, or the mouse. Short key presses
  and clicks move only while held. **P/Escape** pauses; Android
  **Back** pauses during a race and returns from menus.
- Distance earns **2 points/metre**. Every **10 clean passes** earns a
  difficulty-based point bonus (see below).
  Every **20,000 points** awards more time. Time accumulates without a cap: keep
  earning enough points to race indefinitely. Ten-car bonuses never add time directly.
- A crash resets the current clean streak, plays a crash effect, and vibrates
  the device if enabled. Automatic pit recovery costs **4 seconds** while the
  clock continues; distance scoring stops. Re-entry is protected for **1 second**.
- Roads cycle through open road, curves, a narrow motorway, ice, and night.
  Narrow sections use the middle two marked lanes and smoothly constrain the car;
  headlights and rear lights help with night driving.
- A continuous synthesized engine runs while racing. Each clean overtake plays
  a bright C–G chime that rises gently across the clean streak. Ten-pass bonuses
  resolve into a fuller major chord. Ice sliding and
  repairs add quieter effects. **Settings → Sound** controls all audio.
- Roadside trees, shrubs, signs, posts, and rails scroll past; ice adds snow and
  surface markings, and night markers reflect light. Crashes emit brief pixel
  sparks, ice slides leave a subtle trail, and the pit displays a repair indicator.
- Backgrounding freezes the race and audio. Returning requires **Resume Race**.

| Difficulty | Ten-car points | Starting clock | Extra time per 20,000 points |
|---|---:|---:|---:|
| Easy | 8,000 | 180 seconds | 90 seconds |
| Normal | 6,000 | 120 seconds | 60 seconds |
| Hard | 4,000 | 90 seconds | 45 seconds |

Difficulty changes clocks and ten-car point rewards; driving and traffic stay
identical. Each level has its own local high score.
The selected difficulty, sound setting, vibration setting, and records are saved
in `user://profile.cfg`. Records are updated when a race finishes or is ended
from the pause menu. The timer values are mobile adaptation values, not a claim
of exact original timings.

Cars use **32 × 34** native pixel artwork and **30 × 30** scene-authored collision
rectangles. At 56-pixel lane spacing, the combined 30-pixel collision half-width
closes the 28-pixel divider corridor. Road edges clamp using the visual half-width
plus two pixels of clearance (offset limits ±94 on open roads and ±38 on narrow
roads). Repairs centre at x=18 in a 36-pixel bay drawn behind the car.

The sampled [C64 animation](https://www.c64-wiki.com/images/7/70/Lemans_Animation.gif)
shows a 20 × 21 visible car on a 144-pixel main carriageway. Scaling to this game's
224-pixel road gives approximately 31 × 33 pixels; 32 × 34 is a rounded adaptation,
not a verified original collision constant.

## Develop and tune

The main scene is `scenes/game.tscn`. Cars, road strips, traffic pool, audio
players, menus, and HUD are all visible in the Godot editor. Scripts control
their behavior rather than constructing their visuals at runtime.

- `resources/race_settings.tres`: select this resource in the Inspector to tune
  difficulty clocks, speed, steering, repairs, scoring, and traffic intervals.
  Difficulty-array order is **Easy, Normal, Hard**.
- `RaceSession`: distance, clean-pass bonuses, timer thresholds, and race totals.
- `PlayerCar`: continuous steering, per-control held directions, and ice momentum; `RaceRoad`: shared lane
  geometry, road variants, and scrolling. `RoadStrip` caches its visual nodes.
- `RaceTraffic` / `TrafficCar`: 24 reusable cars, spacing, indicators,
  overtakes, and forgiving collision bounds. Narrow-road traffic has equal
  relative speeds and at least a 96-pixel gap so it cannot form a traffic wall.
- `GameProfile` / `RaceAudio`: local persistence and audio. Engine levels and
  fade duration are Inspector-editable on the Audio node. Four passing voices
  use separate panning buses, with a -1 dB master limiter and alert ducking.
- `RoadScenery` / `RaceEffects`: 48 reusable scenery instances, four skid particles,
  eight crash particles, and repair animation. These systems are decorative;
  `game.gd` coordinates their state with the race phases.

Passing rewards last **0.20 seconds** and use semitone steps
**0, 0, 2, 2, 4, 4, 5, 5, 7, 7** across ten clean passes. Each passing voice keeps
its own pitch and stereo position. The **0.72-second** bonus uses a C–E–G–C
ascent and layered major chord, with the engine ducked throughout. A simultaneous
extra-time award updates the HUD immediately; its chime waits for bonus completion.
Mute, pause/backgrounding, restart, and finish cancel pending reward audio.

For a listening review, generate a preview of the actual Godot audio mix:

```sh
godot --path . --script tests/reward_preview.gd
```

`builds/audio/le-manz-reward-preview.wav` contains about 12 seconds: a ten-pass
buildup and bonus alone, a short gap, then the same sequence over the engine.
Generated previews and Android builds are ignored by Git and excluded from exports.
Phone-speaker listening quality still needs a direct listening check.

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
**Regenerating scenes overwrites manual edits to those scenes, the theme, and the
bus layout.**
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
godot --path . --script tests/audio_mix.gd
godot --path . --script tests/capture.gd -- --view=night --out=/tmp/le-manz-night.png
```

The integration suite covers difficulty clocks/bonuses, scoring, persistence,
continuous steering, short presses, ice momentum, road boundaries and narrowing,
multi-touch event handling, pit recovery,
expiry, restart, background notifications, Android Back, traffic spacing,
and complete races, audio state transitions, scenery bounds, and effects. It uses isolated `/tmp` profiles rather than your game saves.
The rendering script captures real scene layouts; views include `title`, `help`,
`settings`, `pause`, `results`, `countdown`, `road`, `curves`, `narrow`, `ice`, `night`, `crash1`, `crash2`, `pit`, `ice_slide`, `reward`, and `endurance`.

Validation on **10 October 2026**:

The earlier engine was found to stop after one second: WAV import mode **1** is
Disabled, whereas **2** is Forward. All three sustained effects now use mode 2,
and the generator preserves that setting. The enum distinction is documented in
[Godot's WAV importer](https://github.com/godotengine/godot/blob/master/editor/import/resource_importer_wav.cpp).


- 809 integration checks passed, including complete races on all three levels,
  timer bonuses, records, releases over UI, cancelled touches, and pause/restart.
  Divider and edge collision checks cover open and narrow roads. A 60 Hz simulation
  steers past eight alternating narrow obstacles spaced exactly 96 pixels apart.
  Blocked spawn retries and narrowing gap enforcement also pass. Reward checks cover
  all ten pitches, rollover, crash reset, independent overlapping voices, bonus
  completion, immediate time awards, and deferred-cue cancellation.
- The real-output audio test passed: engine output continues beyond its loop,
  passing sweeps pan left/right, and overlapping effects peak at **0.8092**
  (approximately -1.84 dBFS). Engine loop RMS was **0.1344**; muted peak was **0**.
  This test requires a working desktop audio driver and measures the digital mix,
  rather than speaker listening quality.
- Rendered and inspected menus, countdown, and every road variant at approximately
  **9:16**, **9:20**, and **3:4** using actual offscreen Godot scene rendering.
  Add `--size=280x622` or `--size=360x480` to the capture command for these sizes.
- Debug APK export and signature verification passed. The APK manifest requires
  portrait orientation, ARM64, and the vibration permission.
- Installed and exercised on a **Samsung SM-A176B (1080 × 2340)**. The top HUD
  clears the camera cutout. Touch menus, held steering between lanes, short-press
  movement, ice hold/release drift, pause, restart, and explicit resume
  after background verified.
- The enlarged build was installed and tested again: an 80 ms left press moved
  only about 12 logical pixels; a 900 ms hold moved toward the edge. Collisions
  triggered automatic recovery, and the enlarged repair sprite remained visible
  inside its bay. Backgrounding returned to the resume screen.
- The enhanced build was installed on the same Samsung device. Sound toggling
  saved correctly and was restored to ON. Android reported an active, unmuted
  **44.1 kHz stereo** OpenSL ES media output after racing started. This confirms
  output initialization; audible speaker quality is still unverified. Touch
  steering, pause, explicit resume, snowy scenery, and reflective night scenery
  were exercised again.
- The reward-audio APK was rebuilt, signed, and installed on the same device.
  Race startup initialized active unmuted stereo output; pause and returning from
  background displayed the resume screen. Listening previews are excluded from
  the APK. The generated stereo preview lasts **12.07 seconds**, with peak **0.4784**;
  it records the actual controller and master bus rather than an approximate mix.
- Android vibration history confirms completed **250 ms** crash requests,
  including two crashes in the enlarged build.
- With the difficulty-based ten-car rewards, seed-1982 collision-free simulation
  reaches its first score-based time award at **24.6s / 24.6s / 38.2s** on
  Easy / Normal / Hard. Ten-minute simulations cover six complete road cycles
  and 848 passes each; all remain active, with the following results:

  | Difficulty | Score after 600s | Time remaining |
  |---|---:|---:|
  | Easy | 731,999 | 2,820 seconds |
  | Normal | 563,999 | 1,200 seconds |
  | Hard | 395,999 | 345 seconds |

  Collision protection is deliberately enabled in these pacing simulations;
  they establish scoring opportunity, not human ability to avoid traffic.
  Crash-heavy stationary runs still expire: Easy finishes after 270s with
  24,924 points / 122 passes / 45 crashes (one time extension); Normal after 120s
  with 10,581 / 60 / 19; Hard after 90s with 7,664 / 47 / 14.
- The final difficulty-reward APK was debug-signature verified and installed on
  the Samsung SM-A176B. Race startup, the Easy 8,000-point instructions, crash/pit
  rendering, and the pause screen after backgrounding were checked; Godot logged
  no runtime errors. Ten-car reward/threshold ordering and long-run balance were
  verified by desktop integration tests, not a clean physical-device playthrough.
- Updated instructions, combined points/time feedback, and long-run HUD displays
  were rendered and inspected at 9:16, 9:20, and 3:4. The dashboard abbreviates
  large values using K/M (and larger units); results and records retain exact
  scores. Time units remain seconds even when abbreviated.


Subjective audio listening, measured frame pacing, long human difficulty
playtests, physical simultaneous multi-touch, and subjective ice feel remain
unverified. Ice acceleration,
drift, countersteering, and short-press steering are covered by automated tests.
The enhanced device run produced no Godot script or audio errors. Additional devices remain
useful for performance, cutout, and compatibility feedback.

## References

- [C64-Wiki: Le Mans](https://www.c64-wiki.com/wiki/Le_Mans)
- [C64 Online: Le Mans](https://c64online.com/c64-games/le-mans/)
- [Three Fields Entertainment: Le Mans history](https://www.threefieldsentertainment.com/2018/12/07/le-man-commodore-64/)
