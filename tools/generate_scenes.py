#!/usr/bin/env python3
"""Author the inspectable Godot scenes. No visible nodes are built at runtime."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def save(path, text):
    (ROOT / path).write_text(text)


save("resources/retro_theme.tres", '''[gd_resource type="Theme" load_steps=7 format=3]
[ext_resource type="FontFile" path="res://assets/font/retro.fnt" id="1"]
[sub_resource type="StyleBoxFlat" id="normal"]
bg_color = Color(0.15, 0.18, 0.29, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 2
border_color = Color(0.43, 0.48, 0.62, 1)
[sub_resource type="StyleBoxFlat" id="hover"]
bg_color = Color(0.22, 0.27, 0.38, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 2
border_color = Color(0.43, 0.80, 0.83, 1)
[sub_resource type="StyleBoxFlat" id="pressed"]
bg_color = Color(0.34, 0.20, 0.29, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 2
border_color = Color(0.85, 0.84, 0.43, 1)
[sub_resource type="StyleBoxFlat" id="focus"]
bg_color = Color(0, 0, 0, 0)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.85, 0.84, 0.43, 1)
[sub_resource type="StyleBoxFlat" id="panel"]
bg_color = Color(0.09, 0.10, 0.17, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.56, 0.50, 0.81, 1)
[resource]
default_font = ExtResource("1")
default_font_size = 8
Button/colors/font_color = Color(0.93, 0.93, 0.80, 1)
Button/colors/font_hover_color = Color(1, 1, 1, 1)
Button/colors/font_pressed_color = Color(0.85, 0.84, 0.43, 1)
Button/styles/normal = SubResource("normal")
Button/styles/hover = SubResource("hover")
Button/styles/pressed = SubResource("pressed")
Button/styles/focus = SubResource("focus")
Label/colors/font_color = Color(0.93, 0.93, 0.80, 1)
Panel/styles/panel = SubResource("panel")
''')

car_header = '''[gd_scene load_steps=5 format=3]
[ext_resource type="Script" path="res://scripts/{script}" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/{texture}" id="2"]
[ext_resource type="Texture2D" path="res://assets/art/lights.svg" id="3"]
[sub_resource type="RectangleShape2D" id="hit"]
size = Vector2(10, 18)
[node name="{name}" type="Area2D"]
collision_layer = 0
collision_mask = 0
script = ExtResource("1")
[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2")
{sprite_options}
[node name="Hitbox" type="CollisionShape2D" parent="."]
shape = SubResource("hit")
'''
save("scenes/player_car.tscn", car_header.format(script="player_car.gd", texture="player.svg", name="Player", sprite_options='hframes = 3\nmodulate = Color(0.95, 0.35, 0.36, 1)') + '''[node name="Headlights" type="Polygon2D" parent="."]
visible = false
z_index = -1
polygon = PackedVector2Array(-4, -12, -46, -100, 46, -100, 4, -12)
color = Color(0.93, 0.93, 0.80, 0.13)
''')
traffic_scene = car_header.format(script="traffic_car.gd", texture="traffic.svg", name="TrafficCar", sprite_options="")
traffic_scene = traffic_scene.replace("load_steps=5", "load_steps=6")
traffic_scene = traffic_scene.replace('[sub_resource type="RectangleShape2D"', '[ext_resource type="Texture2D" path="res://assets/art/indicator.svg" id="4"]\n[sub_resource type="RectangleShape2D"')
traffic_scene += '''[node name="RearLights" type="Sprite2D" parent="."]
texture = ExtResource("3")
[node name="Indicator" type="Sprite2D" parent="."]
texture = ExtResource("4")
position = Vector2(6, 6)
visible = false
'''
save("scenes/traffic_car.tscn", traffic_scene)
pool = '''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/traffic.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/traffic_car.tscn" id="2"]
[node name="Traffic" type="Node2D"]
script = ExtResource("1")
'''
for i in range(24):
    pool += f'[node name="Car{i:02}" parent="." instance=ExtResource("2")]\nvisible = false\n'
save("scenes/traffic.tscn", pool)

# Reuse one inspectable strip scene instead of duplicating its visual structure.
strip = '''[gd_scene load_steps=6 format=3]
[ext_resource type="Script" path="res://scripts/road_strip.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/pixel.svg" id="2"]
[ext_resource type="Texture2D" path="res://assets/art/kerb.svg" id="3"]
[ext_resource type="Texture2D" path="res://assets/art/dash.svg" id="4"]
[ext_resource type="Texture2D" path="res://assets/art/tree.svg" id="5"]
[node name="RoadStrip" type="Node2D"]
script = ExtResource("1")
'''
for name, resource, x, scale in [("Grass", 2, 140, 280), ("Surface", 2, 140, 224), ("LeftEdge", 3, 28, 1), ("RightEdge", 3, 252, 1), ("Dash0", 4, 84, 1), ("Dash1", 4, 140, 1), ("Dash2", 4, 196, 1), ("Scenery", 5, 8, 1)]:
    strip += f'[node name="{name}" type="Sprite2D" parent="."]\ntexture = ExtResource("{resource}")\nposition = Vector2({x}, 0)\nscale = Vector2({scale}, 1)\n'
save("scenes/road_strip.tscn", strip)
road = '''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/road.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/road_strip.tscn" id="2"]
[node name="Road" type="Node2D"]
script = ExtResource("1")
[node name="Rows" type="Node2D" parent="."]
'''
for i in range(160):
    road += f'[node name="Strip{i:02}" parent="Rows" instance=ExtResource("2")]\nposition = Vector2(0, {64 + i * 8 + 4})\n'
save("scenes/road.tscn", road)

audio = '[gd_scene load_steps=8 format=3]\n[ext_resource type="Script" path="res://scripts/audio.gd" id="1"]\n'
effects = [("Engine", "engine", -7), ("Crash", "crash", -3), ("Bonus", "bonus", -6), ("ExtraTime", "extra_time", -6), ("Finish", "finish", -6), ("Tick", "tick", -9)]
for index, (_, file, _) in enumerate(effects, 2):
    audio += f'[ext_resource type="AudioStream" path="res://assets/audio/{file}.wav" id="{index}"]\n'
audio += '[node name="Audio" type="Node"]\nscript = ExtResource("1")\n'
for index, (name, _, volume) in enumerate(effects, 2):
    audio += f'[node name="{name}" type="AudioStreamPlayer" parent="."]\nstream = ExtResource("{index}")\nvolume_db = {volume}.0\n'
save("scenes/audio.tscn", audio)

# The complete interface is authored here as scene nodes, not added by GDScript.
main = '''[gd_scene load_steps=11 format=3]
[ext_resource type="Script" path="res://scripts/game.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/road.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/player_car.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/traffic.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/audio.tscn" id="5"]
[ext_resource type="Theme" path="res://resources/retro_theme.tres" id="6"]
[ext_resource type="Texture2D" path="res://assets/art/logo.svg" id="7"]
[ext_resource type="Texture2D" path="res://assets/art/finish.svg" id="8"]
[ext_resource type="Resource" path="res://resources/race_settings.tres" id="9"]
[ext_resource type="Script" path="res://scripts/profile.gd" id="10"]
[node name="LeManz" type="Node2D"]
script = ExtResource("1")
settings = ExtResource("9")
[node name="Road" parent="." instance=ExtResource("2")]
[node name="Traffic" parent="." instance=ExtResource("4")]
[node name="Player" parent="." instance=ExtResource("3")]
position = Vector2(168, 400)
z_index = 2
[node name="FinishLine" type="Sprite2D" parent="."]
visible = false
texture = ExtResource("8")
position = Vector2(140, -16)
[node name="Audio" parent="." instance=ExtResource("5")]
[node name="Profile" type="Node" parent="."]
script = ExtResource("10")
[node name="UI" type="CanvasLayer" parent="."]
'''


def node(name, kind, parent, x, y, w, h, properties=""):
    global main
    main += f'[node name="{name}" type="{kind}" parent="{parent}"]\noffset_left = {x}.0\noffset_top = {y}.0\noffset_right = {x + w}.0\noffset_bottom = {y + h}.0\n'
    main += 'theme = ExtResource("6")\n'
    if kind in ("Control", "Label", "ColorRect", "TextureRect"):
        main += "mouse_filter = 2\n"
    main += properties + "\n"


def label(name, parent, text, x, y, w, h=12, colour=None, size=8):
    props = f'text = {json.dumps(text)}\nhorizontal_alignment = 1\nvertical_alignment = 1\ntheme_override_font_sizes/font_size = {size}'
    if colour:
        props += f'\ntheme_override_colors/font_color = Color({colour})'
    node(name, "Label", parent, x, y, w, h, props)


def button(name, parent, text, x, y, w, h=26, toggle=False):
    node(name, "Button", parent, x, y, w, h, f'text = {json.dumps(text)}\ntoggle_mode = {str(toggle).lower()}')


def panel(name, heading):
    node(name, "Panel", "UI", 12, 80, 256, 360, "visible = false")
    label("Heading", f"UI/{name}", heading, 8, 18, 240, 24, "0.85, 0.84, 0.43, 1", 16)
    node("Rule", "ColorRect", f"UI/{name}", 16, 50, 224, 1, "color = Color(0.56, 0.50, 0.81, 1)")


node("HUD", "Control", "UI", 0, 0, 280, 480)
node("Instruments", "ColorRect", "UI/HUD", 0, 0, 280, 64, "color = Color(0.13, 0.13, 0.20, 1)")
node("Divider", "ColorRect", "UI/HUD", 0, 62, 280, 2, "color = Color(0.69, 0.24, 0.33, 1)")
label("ScoreCaption", "UI/HUD", "SCORE", 8, 4, 100, 10, "0.56, 0.50, 0.81, 1")
label("Score", "UI/HUD", "000000", 8, 16, 100, 18, size=16)
label("TimeCaption", "UI/HUD", "TIME", 112, 4, 64, 10, "0.56, 0.50, 0.81, 1")
label("Time", "UI/HUD", "120", 112, 16, 64, 18, "0.85, 0.84, 0.43, 1", 16)
button("PauseButton", "UI/HUD", "PAUSE", 190, 4, 82, 30)
label("SpeedCaption", "UI/HUD", "KM/H", 8, 35, 38, 10)
label("Speed", "UI/HUD", "180", 48, 35, 30, 10)
label("PassCaption", "UI/HUD", "CLEAN", 88, 35, 36, 10)
label("Passes", "UI/HUD", "0 / 10", 130, 35, 48, 10)
label("Difficulty", "UI/HUD", "NORMAL", 190, 36, 82, 10, "0.43, 0.80, 0.83, 1")
label("Section", "UI/HUD", "OPEN ROAD", 8, 49, 264, 10)
label("LeftHint", "UI/HUD", "< HOLD / TAP", 8, 462, 126, 12)
label("RightHint", "UI/HUD", "HOLD / TAP >", 146, 462, 126, 12)
node("NoticeBacking", "ColorRect", "UI/HUD", 8, 70, 264, 24, "visible = false\ncolor = Color(0.13, 0.13, 0.20, 0.94)")
label("Notice", "UI/HUD", "", 8, 70, 264, 24, "0.85, 0.84, 0.43, 1")
node("BannerBacking", "ColorRect", "UI/HUD", 54, 180, 172, 38, "visible = false\ncolor = Color(0.13, 0.13, 0.20, 0.92)")
label("Banner", "UI/HUD", "", 8, 184, 264, 30, "0.93, 0.93, 0.80, 1", 16)
node("Pit", "Panel", "UI/HUD", 0, 372, 26, 44, "mouse_filter = 2")
label("PitLabel", "UI/HUD/Pit", "PIT", 1, 4, 24)
label("PitMark", "UI/HUD/Pit", "+", 1, 20, 24, 16, "0.43, 0.80, 0.83, 1", 16)

panel("Title", "")
node("Logo", "TextureRect", "UI/Title", 45, 16, 166, 30, 'texture = ExtResource("7")\nexpand_mode = 1')
label("Subtitle", "UI/Title", "THE CLASSIC ROAD.\nA NEW RACE.", 8, 58, 240, 26, "0.43, 0.80, 0.83, 1")
label("DifficultyLabel", "UI/Title", "SELECT DIFFICULTY", 8, 94, 240)
for name, x in [("Easy", 16), ("Normal", 92), ("Hard", 168)]:
    button(name, "UI/Title", name.upper(), x, 114, 72, 32, True)
label("Record", "UI/Title", "BEST 000000 / TIME 120", 8, 156, 240)
button("Start", "UI/Title", "START RACE >", 36, 190, 184, 36)
button("Help", "UI/Title", "HOW TO PLAY", 36, 240, 184, 36)
button("Settings", "UI/Title", "SETTINGS", 36, 290, 184, 36)

panel("Help", "HOW TO PLAY")
label("Text", "UI/Help", "HOLD LEFT / RIGHT: STEER\nQUICK TAP: MOVE ONE LANE\n\nICE: RELEASE TO SLIDE.\nCOUNTERSTEER TO BRAKE.\n\n180 KM/H. NO GAS PEDAL.\n10 CLEAN PASSES: +1000\n20,000 POINTS: EXTRA TIME\n\nPIT REPAIR: 4 SECONDS.\nTHE CLOCK KEEPS RUNNING!", 8, 64, 240, 212)
button("Back", "UI/Help", "BACK", 36, 304, 184, 36)

panel("Settings", "SETTINGS")
button("Sound", "UI/Settings", "SOUND: ON", 24, 88, 208, 40)
button("Vibration", "UI/Settings", "VIBRATION: ON", 24, 150, 208, 40)
label("Caption", "UI/Settings", "OPTIONS ARE SAVED\nON THIS DEVICE", 8, 214, 240, 32)
button("Back", "UI/Settings", "BACK", 36, 304, 184, 36)

panel("Pause", "RACE PAUSED")
label("Caption", "UI/Pause", "TAKE A BREATHER.\nTHE CLOCK IS STOPPED.", 8, 66, 240, 32)
button("Resume", "UI/Pause", "RESUME RACE >", 36, 124, 184, 40)
button("Settings", "UI/Pause", "SETTINGS", 36, 190, 184, 40)
button("Quit", "UI/Pause", "END RACE", 36, 270, 184, 40)

panel("Results", "FINISH!")
label("Difficulty", "UI/Results", "NORMAL", 8, 68, 240, 12, "0.43, 0.80, 0.83, 1")
label("Score", "UI/Results", "000000", 8, 98, 240, 30, "0.85, 0.84, 0.43, 1", 24)
label("Record", "UI/Results", "NEW BEST!", 8, 144, 240, 12)
label("Stats", "UI/Results", "0 PASSES / 0 CRASHES", 8, 174, 240, 12)
button("Retry", "UI/Results", "RACE AGAIN >", 36, 228, 184, 40)
button("Title", "UI/Results", "MAIN MENU", 36, 294, 184, 40)
save("scenes/game.tscn", main)
print("Generated reusable portrait car, road, traffic, audio and game scenes.")
