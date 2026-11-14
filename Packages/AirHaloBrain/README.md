# AirHaloBrain

The gesture "brain" of AirHalo: **21 hand points in, mouse/trackpad commands out.**

It uses Foundation only, with no camera, Vision, AppKit or CoreGraphics code. A port to
Windows, Linux or Android rewrites this logic (a few hundred lines) and checks it against
the same rules and the same recorded sessions in `Tests/AirHaloBrainTests/Fixtures`.

```
camera → hand tracker (Apple Vision / MediaPipe) → HandFrame → GestureEngine → [Command] → OS input
                                                                          ↘ HaloState → halo cursor
```

## Input: `HandFrame`

- 21 joints per hand, in **MediaPipe order** (`Joint`): wrist, thumb ×4, then index, middle,
  ring and little ×4 each (knuckle → tip).
- Origin top-left, y down, **mirrored like a selfie** (move your hand right → x grows).
- Units are fractions of the image **height**: y is 0…1 and x is 0…aspect.
- A joint with confidence below `minJointConfidence` (0.3) counts as missing.

## Measurements

- **Hand scale** = wrist → middle knuckle. Every threshold is in hand scales, so it works
  near or far from the camera.
- **Palm centre** = average of the wrist and four knuckles. The pointer follows this point,
  because it barely moves when you pinch.
- **Pinch** = thumb tip → fingertip ÷ hand scale. Closes below `pinchClose` (0.25) and
  opens above `pinchOpen` (0.40). The gap stops flicker.
- **Finger extension** = wrist → tip ÷ wrist → knuckle. Extended above 1.5, folded below 1.3.

## Gestures

| Action | Gesture | Rule |
|---|---|---|
| Engage | Open palm (four fingers straight) | Held `engageHold` 0.3 s. Nothing happens before this |
| Disengage | Fist, or hand gone | Fist held 0.5 s, or no hand for 1 s. Held buttons are released |
| Move | Move the hand | Palm centre → One-Euro filter → acceleration curve (relative) or zone → screen (absolute) |
| Left click | Thumb–index pinch | Button down on close, up on open. Pointer frozen 0.12 s after closing |
| Double click | Two pinches | Within the system double-click time and 6 pt of travel |
| Drag | Pinch held 0.3 s, or moved > 0.02 units | Movement while pinched drags |
| Right click | Thumb–middle pinch | Only when the index is clearly apart |
| Scroll | Index + middle up, ring + little down | Held 0.15 s. Hand movement × `scrollGain`. Natural direction. Momentum after a fast release |
| Zoom | Both hands pinching | Distance change of ±18% → one zoom step in or out |
| Switch Space | Fast sideways flick, open palm | ≥ 1.6 hand scales within 0.25 s. Hand left → Space on the right. The pointer movement caused by the flick is undone |

**Two hands in view never click.** Pinches only zoom, so reaching in with a second hand
can't click by accident.

## Output: `Command`

`move(dx, dy)` in points · `moveTo(x, y)` 0…1 · `buttonDown/Up(button, clickCount)` ·
`scroll(dx, dy, phase)` · `zoom(in/out)` · `switchSpace(left/right)`.

`releaseAll()` returns the commands that let go of anything held. Call it when pausing.

## Tuning

Every number lives in `BrainSettings`. The app saves the user's copy as JSON.

## Tests

```bash
swift test
```
