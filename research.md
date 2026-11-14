# AirHalo — Research Report

*Final name: **AirHalo** (working name was "AirTouch"). Research done 2026-11-15. Nothing has been built, registered or bought yet.*

**The idea:** a macOS app that tracks your hand with the webcam and uses it as a mouse, a trackpad and, as far as possible, a touch screen (hover-pointer mode). It also lets you "grab" a picture on the Mac and "throw" it to a nearby iPhone that runs a companion app, which plays a catch animation. An Android TV version comes later, probably using the phone as the camera.

**MVP scope (decided 2026-11-15):** air mouse and trackpad gestures only. See section 4.

Already decided: hand tracking uses Apple Vision (21 joints); the cursor is driven with CGEvent plus Accessibility permission; transfer uses Multipeer Connectivity, because AirDrop's receive screen can't be customised; Macs have no UWB chip, so you can't aim a throw at a phone by its position.

---

## 1. Similar projects

### 1.1 Webcam "air mouse" apps (macOS / Windows)

| Project | What it is | Strengths | Weaknesses |
|---|---|---|---|
| **Airpoint** (airpoint.app) | Commercial macOS app (macOS 12+, Apple Silicon and Intel; Windows "coming soon"). Launched on Product Hunt in March 2026. Open web SDK (Apache-2.0) followed in May 2026. | Closest competitor. Cursor, click, right-click, scroll, zoom, drag, shortcuts, macros. Has an SDK and pitches itself for AI agents too. | Paid "AirMouse" ML model licence. Early reviews mention unintended motion: an index finger moving on a resting hand still moves the cursor. Few reviews so far. **It also uses one of our candidate names.** |
| **Pawvis** (alexandriax/pawvis) | Free MIT Swift app, macOS 14+. Launched August 2026. | Native and on-device. Open palm moves the cursor, an index-finger dip clicks, two folded fingers scroll. You can train custom gestures and set per-app bindings. Works with any camera, including Continuity Camera. | Very new, about 24 stars and 2 contributors. Reviewers say it takes practice to be precise. Not on the Mac App Store. |
| **Gstrl** | Free MIT Swift app, macOS 14+, built on Apple Vision. | Rich gesture set: pinch to move, left pinch to click, hold for right-click, flicks for arrow keys, fist for dictation, both fists for an AI agent, two hands to drag. | You have to build it from source (`make install`). It's a hobby project with a steep gesture-learning curve. |
| **ControlAir** (eyeSight, 2015) and **Flutter** | Free Mac App Store gesture apps. | Proved that gesture apps can get into the Mac App Store. | Media playback only, no cursor. Complaints about an always-on camera and unreliable left-hand detection. Both are effectively abandoned. |
| **macOS Head Pointer** (built in) | Apple accessibility feature: head movement moves the pointer, using the webcam. | Free, built in, and pauses on its own when you touch the mouse. | Head, not hands. Jittery in poor light. Pointer only. |
| **Google Project Gameface** | Open-source head/face cursor built on MediaPipe, for Windows and Android. | Well funded, good accessibility design. | Face, not hands. No macOS build. |
| **Camera Mouse** | Free Windows head-tracking mouse for accessibility. | Long-lived and trusted. | Windows only, head only. |
| **GitHub MediaPipe scripts** (e.g. small-cactus/handTrack, rishraks/virtual_mouse, maanjk/hand-gesture-virtual-mouse, Kazuhito00/simple-virtual-mouse, Handroller, DedoMouse, Aircursor, Notmytypeo/AirPoint) | Hundreds of student and hobby projects built on OpenCV, MediaPipe Hands and PyAutoGUI. | Show the basic gesture vocabulary: pinch to click, fist to grab, two fingers to scroll. | Demo quality. Little or no smoothing, so the cursor jitters. High latency through Python and PyAutoGUI. You need a Python setup. Most stop being updated after a semester. |

**Common complaints across this category:**
- **Jitter.** A tracked hand keeps moving even when you hold it still, and tremor makes it worse. Every serious project ends up adding smoothing.
- **Midas touch.** Every movement gets read as input, as in the Airpoint feedback.
- **Gorilla arm.** Holding an arm up gets tiring within minutes. Smart-glasses vendors tell users to rest every 20–30 minutes.
- **Lighting.** Tracking gets worse in dim or backlit rooms.
- **Gestures are hard to learn.**
- **Privacy worries** about an always-on camera.

### 1.2 Hardware

| Product | Strengths | Weaknesses |
|---|---|---|
| **Ultraleap / Leap Motion Controller 2** (launched 2023, $139; now listed at about $219) | Best consumer hand tracking available: IR stereo, works in the dark, high accuracy. macOS SDK v6.2 (September 2025) for Apple Silicon and Intel. | Extra hardware to buy and carry. Few Mac consumer apps. **The company is in trouble:** about half its staff laid off in 2024, the hand-tracking IP sold to SIM IP in early 2025, and the company reportedly bought by ROLI in November 2025 (one wiki source). Some retailers list the device as discontinued. Long-term support is uncertain, which is an opening for a software-only product. |
| **AirBar (Neonode)** ($99, 2017) | An IR light bar under the screen gives real touch and swipe on a laptop with no camera. Plug and play. Reviewers found it accurate. | The Mac model only fits pre-2018 13" MacBook Airs and attaches with permanent magnets. macOS isn't designed for touch, so menu items get triggered by mistake. Effectively dead for current Macs. |

### 1.3 Research: Project Sistine (2018)

- **How it works:** Anish Athalye and colleagues built it in about 16 hours for $1 of parts: a small mirror on a paper-plate hinge, angled so the MacBook's webcam looks down at the screen. On a glossy screen a finger meets its own reflection. The software uses skin-colour thresholding and contour finding, then compares the finger with its reflection to tell touch from hover. A one-time calibration (touch the dots, homography fitted with RANSAC) maps the camera image to the screen, and touches are sent as mouse events.
- **Limits:** The webcam was 480p, the mirror only saw part of the screen, and it was much less smooth and accurate than a real touch screen. The authors said a higher-resolution camera and a curved mirror would be needed. It's MIT-licensed and was never turned into a product.
- **Lesson for us:** True touch needs the camera to see the screen surface. That points to an optional "mirror clip" accessory mode as a later stretch goal, with hover-pointer as the default.

### 1.4 Gesture-based transfer

| Feature / app | Strengths | Weaknesses |
|---|---|---|
| **Huawei "AI Teleportation" / Air Gesture File Transfer** (Mate 70, Mate X6, MatePad Pro 13.2, later Pura 70 and Mate 60) | The closest match to our throw feature. Palm to fist grabs, which also takes a screenshot. Move over to the other device and open your hand to drop it there. Feels magical. | Only works inside Huawei's ecosystem, needs the same Huawei ID and probably the same Wi-Fi. Rolled out in batches. On the Pura X it conflicted with Air Screenshot, so you could only turn on one at a time. |
| **Apple AirDrop / NameDrop** (iOS 17+) | "Bringing Devices Together" shares contacts and content just by holding phones close. Polished and trusted. | Phone-to-phone or phone-to-watch only, triggered by touch, no gesture. Developers can't customise the receive screen. Macs don't take part in proximity sharing. |
| **Magic File Transfer (Fadlan Send)** | Web PWA. MediaPipe clench to grab, open hand to throw. On-device. Works as an Android share target. | Experimental, tiny user base, browser only. |
| **Older "bump / swipe" apps** (Bump, WaferApp, Swyp, Dukto) and research (UW AirLink, mid-air wave to send) | Show that people like physical-gesture transfer. | Mostly dead. Bump was shut down in 2014. |

### 1.5 TV hand control (for the Android TV version)

| Product | Strengths | Weaknesses |
|---|---|---|
| **Samsung Smart Interaction (2013)** and later **Gesture Interaction** (2022 QN900B/QN800B/The Frame, USA and Korea only) | Camera-based gesture control on a TV. | Needed a separate USB camera. Limited models and countries. Samsung has since moved to a watch-based pointer mode that needs no camera, which suggests camera gestures didn't catch on. |
| **Samsung Universal Gestures** (2025 TVs U8000F and up, with a Galaxy Watch) and **WowMouse** (Wear OS) | No camera needed. Watch IMU detects pinches and wrist rotation. | You need a smartwatch. Pointer only. |
| **LG Magic Remote** | The motion-pointer remote is very popular. | Hold-in-hand remote, not free-hand. |
| **Research: MediaPipe + ADB control of Android TV** | Shows that webcam landmarks plus ADB over Wi-Fi can drive Android TV. | Academic prototype, not an app. |

**Takeaway:** no shipping camera-based hand-control app exists for Android TV. Using the phone as the camera is an open gap.

A second check found phone gesture apps (Spatial Touch, Touchless: Gesture Controller), but they only control the phone itself, not a TV. TV gesture control today means a smartwatch or Samsung's USB camera.

### 1.6 Second-round findings (2026-11-15)

A deeper web search found rivals the first round missed and design ideas worth borrowing. **Caveat:** most of this comes from the makers' own pages and Product Hunt comments. There are almost no independent reviews, so try the free apps yourself.

**New Mac rivals:**

| App | Strengths | Weaknesses |
|---|---|---|
| **AirTouch** (airtouchapp.com, Product Hunt) | Ten gestures: point, pinch to click, swipe between Spaces, "snap to close". Dictation by touching two fingers to your temple. | Unclear whether it will be free or paid. Mac only and early. Shares a name with the BLUETAG Play app. |
| **Air Control** (pathakcodes/air-control) | Apple Vision, on-device. Point, click, scroll, switch desktops. Free Apple Silicon beta. | Beta (0.6.0). Not notarised: users have to use "Open Anyway". |
| **Conductor** (dev-talix/conductor) | Menu bar app on Apple Vision. Pinch for click, drag, scroll and zoom. | Small project. |
| **Cenno** (sapucaialuann/cenno) | Open source. Gestures for Spaces, Mission Control, Spotlight and screen lock. | Not notarised, so macOS blocks the first launch. |
| **halo** (off9rid/halo) | Webcam gestures with MediaPipe, on-device: window moves, media, shortcuts. | Few details found. **Its name is very close to AirHalo** (see 3.4). |
| **gesture-mac** (Dheeraj-Baghel/gesture-mac) | Apple Vision: pointer, click, drag, right-click, scroll. | Hobby project. |
| **Spatial Touch** (VTouch) | On the App Store. Has a filter-strength slider: lower is easier, higher is more stable. | Built for iPad, not really for Mac. Rated 2.9/5 from 13 US ratings. |

**More detail on known rivals:**
- **Airpoint:** claims custom AI models filter out accidental moves, and runs fully on-device. Offers a command-line tool (`airpoint tracking on/off`) and a cursor-sensitivity setting. Product Hunt users keep asking about drift, accidental clicks and responsiveness, and no developer answers were found.
- **Pawvis:** the cursor follows only an open hand, which is a simple on/off switch. Signed and notarised. Has dwell-clicking for people with limited movement. A Product Hunt user asked about accidental triggers during video calls, with no answer found.

**Touch and hover design to learn from:**

| Source | Lesson |
|---|---|
| **Ultraleap TouchFree** (touchless kiosk software) | The closest thing to the AirHalo halo. The cursor is a ring that shrinks toward its centre as the finger pushes forward, then changes colour and size on click. Their user research found that **people instinctively "tap" in the air even when hover-to-click is offered**, so they built "Air Push" to handle many tap speeds. A click only counts once the finger pulls back. Near a real screen they suggest a roughly 5 cm interaction zone, with the cursor fading near its edge. |
| **Apple Vision Pro** (look and pinch) | The pinch is so small the hand can rest in your lap. Designers warn it feels fine in a demo but tiring after an hour, so "design for the second hour". Eye tracking only reads where you're looking at the moment you pinch, which keeps it from jumping around. |
| **AirTouch for Snap Spectacles** (prototype) | You calibrate by pinching the screen's four corners. Then a poke on that invisible surface clicks, and holding drags. |

**Gesture transfer, updated:**
- **Huawei Grab & drop now works on PCs** running HarmonyOS 5.1 or later. Other limits: devices more than 40 cm apart, screens on and unlocked. It fails if both devices see the grab. The TechARP review found it limited to a few file types and weaker than AirDrop or Quick Share.
- **Gesture Drop** (kiranbk0625/gesture-drop-Innovation): make a fist on the computer and copied text appears in the phone's browser. Hobby project.
- **Hoccer** (Berlin, 2010) supported slide and throw gestures between phones and PCs. Like Bump, it's gone.

**What to borrow:**
1. An engage gesture (Pawvis's open hand, Airpoint's clutch), so a resting hand does nothing.
2. TouchFree's shrinking ring with a "poke" click, which is basically the AirHalo halo.
3. Corner-pinch calibration for hover mode.
4. A smoothing-strength slider (Spatial Touch).
5. iPhone as the camera through Continuity Camera (Pawvis). This also sets up the TV version.
6. Dwell-click and other accessibility options.
7. Huawei's palm-to-fist grab and open-hand drop, which people already understand.

**What to avoid:**
1. Accidental input. Pause automatically during video calls, when the real mouse moves, and when no hand has been seen for a while.
2. Too many gestures. Gstrl and AirTouch have ten or more. Start with about four.
3. Unsigned builds. Sign and notarise from day one (Cenno and Air Control get blocked).
4. Huawei's lock-in and gesture conflicts. Make sure only the Mac reacts to a grab, and support pictures, links, text and files.
5. Designing for the demo. Test sessions of one to two hours for tiredness.

---

## 2. Gaps and opportunities (where we can win)

1. **A native, polished, smooth app.** Most rivals are Python demos. A Swift app on Apple Vision with proper filtering (One-Euro filter, velocity-dependent gain), low latency and a signed, notarised build is already above most of the field.
2. **Fix the Midas-touch and gorilla-arm problems directly:**
   - Use an engage/clutch gesture (for example, pinch-hold to "grab" the cursor) so idle movement does nothing.
   - Add a trackpad-style relative mode that works with your elbow on the desk.
   - Pause automatically when the real mouse moves, the way Head Pointer does.
   - Tune the camera for a hand at rest height.
3. **Make hover-pointer feel like touch:**
   - Show an on-screen hover halo and grow it as the pinch closes.
   - Use a calibration step that maps the hand to the screen.
   - Offer an optional Sistine-style mirror-clip mode for real touch later.
4. **The throw-to-iPhone feature is unique.** Nobody offers gesture grab-and-throw from a Mac to an iPhone. Huawei proves people want it, but it's locked to Huawei (it now also works on HarmonyOS PCs, see 1.6). A Multipeer companion app with throw and catch animations would be our headline feature. It's very demo-friendly and suits social video.
5. **Privacy.** Keep everything on-device, show a visible camera indicator, and pause when idle. These answer the always-on-camera complaints.
6. **The hardware incumbents are weak.** Leap Motion's future is uncertain and AirBar is dead for current Macs, so "no hardware needed" is a strong message.
7. **Android TV, phone as camera.** No real competitor yet, and the phone stays useful as the camera and as a remote.

**Risks to plan for:**
- **Distribution.** Posting events and using Accessibility from a sandboxed Mac App Store app is a grey area. Apple suggests `CGRequestPostEventAccess`, but App Review has rejected CGEvent and Accessibility apps under guidelines 2.4.5 and 2.5.1. Recent peers such as Winq, Pawvis and Gstrl ship as direct downloads. **Plan for Developer ID + notarisation first, and treat the Mac App Store as optional.**
- **A crowded 2026 field.** Airpoint, Pawvis and Gstrl all launched this year. Compete on the throw feature and on polish, not on basic "move the cursor".

---

## 3. Name check

**Method:**
- App Store: iTunes Search API for iOS and Mac (US store).
- Google Play: web search.
- Trademarks: USPTO data through aggregators (Justia, Markinton, TrademarkDir). This is **not** legal clearance.
- GitHub: repository search.
- Domains: DNS lookup only.

### 3.1 Candidate names

| Name | Apps | Companies / products | Trademarks | GitHub | Risk |
|---|---|---|---|---|---|
| **AirTouch** | 7 active iOS apps from Polyaire (air-conditioning controllers, updated 2026). **"AirTouch: Gesture Control" on Google Play** (BLUETAG, 5K+ installs), the same category as ours. | Polyaire AirTouch (AU). Historic AirTouch Communications (a mobile carrier that became part of Vodafone). | Several live AIRTOUCH marks, including JMM Lee Properties in **Class 9** (software/electronics) and Class 38. Close to Apple's "Air" family (AirDrop, AirPlay, AirPods, MacBook Air). | 223 repos, including jing-interactive/AirTouch (Kinect multi-touch, the same concept) and many Polyaire integrations. airtouch.app is taken. | **High** |
| **AirTrack** | AirTrack air-quality app, AirTrack NG / Classic (navigation, on iOS and Mac), many "AirTracker" find-my-AirTag apps. | Several unrelated businesses. | Live marks held by Barcodes LLC (**Class 9**, asset tracking), LEVATA, Sports Inovation and others. | 244 repos; the user `airtrack` owns several. airtrack.app is taken. | **Medium**: no direct gesture clash, but crowded and it reads as "flight/AirTag tracking". |
| **AirPoint** | Magnima AirPoint (Mac and iOS education app). | **Airpoint (airpoint.app) is a direct competitor**: a webcam hand-tracking cursor for macOS, launched 2026. Also GestureTek's older AirPoint gesture hardware. | Live AIRPOINT mark held by Magnima, **Class 9**, registered 2021. | Notmytypeo/AirPoint (MediaPipe gesture mouse), and airpointer projects with 400+ stars. airpoint.app is taken. | **High** (worst practical clash) |
| **TrackPoint** | Several small "TrackPoint" utility apps. | **Lenovo (formerly IBM) TrackPoint**, the famous ThinkPad pointing stick, in exactly our category (pointing devices). | **Registered TRACKPOINT, Reg. 1869262** (1994, live), now owned by Lenovo. Lenovo lists it among its trademarks. | 268 repos, almost all about the ThinkPad nub. | **High**: do not use. |

### 3.2 Alternatives that look free

All of these come from a quick screen across the iOS/Mac App Store, Google Play, GitHub and USPTO aggregators. None of them uses "Air", which avoids Apple's naming.

| Name | Meaning | App Store / Play | Trademarks found | GitHub | Domain | Risk |
|---|---|---|---|---|---|---|
| **Palmcast** | Palm for pointing, cast for throwing. "Cast" also suits the TV version. | None found | None found | 3 repos | .com registered (parked); **.app looks free** | **Low** |
| **Pinchcast** | Pinch is the core gesture; cast for throwing. | None found | None found | 0 repos | .com registered; **.app looks free** | **Low** |
| **Wavecatch** | Wave to point, catch on the phone. | None found (one music app, "CatchWave") | None found | 16 repos | .com registered; **.app looks free** | **Low** |
| **Hoverly** | Matches the hover-pointer mode. | None found | HOVERLY live in Class 21 (housewares, a Chinese trader); a different class | 13 repos | hoverly.app taken; **.com looks free** | **Low–Medium** |
| **Skyhand** | Hand in the air. | None found | SKYHAND live in Class 8 (hand tools); a different class | 17 repos | .com taken; **.app looks free** | **Low–Medium** |

My first-round recommendation was **Palmcast**. The user wanted a catchy, Apple-style name instead, so the search continued.

### 3.3 Apple-style "Air" names

**Is the "Air" prefix allowed?** Apple owns AirDrop, AirPlay, AirPods and MacBook/iPad/iPhone Air, but not "Air" on its own. Apps such as AirParrot Remote, AirServer Connect and Air Buddy are on the App Store, so the prefix is accepted. The rule that matters is **App Review Guideline 5.2.5**: don't look confusingly similar to an Apple product, and don't imply Apple endorses you. So no AirDrop-style icon, and no "iPad Air"-like wording.

| Name | Verdict | Key findings |
|---|---|---|
| AirGrab | Low | No apps. Only a pending "Air grab" mark in Class 41 (entertainment/education). airgrab.com and airgrab.app both looked free. |
| AirCatch | Low | Nothing found. .app looked free; .com taken. |
| AirFling | Low | Only a dead AIRFLING toy mark (Class 28). .app looked free. |
| AirFlick | Low | Nothing found. .app looked free. |
| AirWave | **High** | HPE Aruba **AirWave** network-management software; 5+ App Store apps (AirWave Internet Radio, Airwave AI…); thurasw/airwave, an iOS-to-Windows file-sharing repo (★199). .com and .app taken. |
| AirCast | **High** | Registered **AIRCAST** software mark (Reg. 4814492) for streaming photos and video to consumer devices; 3 "Air Cast" screen-mirror-to-TV apps; DJO/Enovis Aircast medical brand; AirPlay-to-Chromecast "aircast" bridge (★411). .com and .app taken. |
| AirPad | **Medium** | Reads like "iPad Air" reversed and sits next to AirPods, which is a Guideline 5.2.5 risk; Apple has opposed a "POD" mark before. At least 9 AIRPAD filings are dead, several in Class 9 (electronics/software); one pending mark in unrelated classes. Very descriptive, so it may be hard to register. 81 GitHub repos (including a Flipper Zero "Airpad" air mouse). airpad.app taken. |
| AirHover, AirSwish, AirReach | Low | No apps, no trademarks found, 0 GitHub repos, .app looked free. |
| AirGlass, AirSurface | Low (stores only) | No apps; .app looked free. Trademarks not checked. |
| **AirHalo** | **Low** | See below. |

### 3.4 Final choice: **AirHalo**

**Why it fits:**
- The core experience is a hover pointer with a glowing halo under your hand. The halo grows as you pinch, so pointing feels like touch.
- It's short, elegant and Apple-like.
- It works for every platform: AirHalo for Mac, an AirHalo companion app on iPhone, and AirHalo for TV.

**Clearance screen:**
- **App Store (iOS and Mac):** no apps.
- **GitHub:** 0 repos.
- **Domains:** airhalo.app looked free (no DNS); airhalo.com is taken.
- **US trademark:** AIRHALO, Reg. 6807446 (Volkinator Enterprises), Class 11 only (environmental control and air treatment), which is unrelated to software. Aggregator sites disagree on its status, so confirm it in USPTO TSDR.
- **Canadian trademark:** AIR HALO, TMA1127644, also Class 11.
- **Other:** an abandoned 2018 US application for AIR HALO.

**Remaining risk:** low. The only marks are in an unrelated class, but both are "air"-related goods, so search Class 9 and Class 42 closely during clearance.

**New finding (second round):** a GitHub project called **off9rid/halo** is a Mac app controlled by webcam hand gestures, which is the same category. Searches turned up no details about it (no trademark, store listing or activity found). It probably doesn't block AirHalo, but check whether it's active, and mention it to the trademark attorney.

**Before launch:**
1. Have a trademark attorney run a full USPTO/EUIPO (and home-country) clearance search for AIRHALO in Classes 9 and 42.
2. Register airhalo.app and reserve the App Store and Google Play names.
3. Consider filing your own Class 9 mark.

---

## 4. MVP scope

**Decided 2026-11-15:** the first version is **air mouse plus trackpad gestures**. Nothing else.

### 4.1 In the MVP

| Feature | Difficulty | How (first idea) |
|---|---|---|
| **Air mouse:** point to move, pinch to click, pinch-hold to drag, right-click | Easy to build, hard to make smooth | Apple Vision hand pose, then smoothing, then `CGEvent` mouse events. Accessibility permission is needed. |
| **Two-finger scroll** | Medium | `CGEventCreateScrollWheelEvent` with pixel units, so scrolling is smooth rather than in steps. This is a public API. |
| **Pinch to zoom** | Medium | macOS has no public API for faking a trackpad pinch. First choice: send ⌘+ / ⌘− (or ⌘ + scroll in apps that support it). A real pinch would need private APIs: test it, but don't depend on it. |
| **Swipe between Spaces** | Medium | There's no public API for faking the swipe either. Send the default Mission Control shortcuts, ⌃← and ⌃→. Warn the user if those shortcuts are turned off. |

**Must-haves**, taken from the lessons in 1.6. Without these the MVP feels like every other demo:
1. **An engage gesture.** A resting hand does nothing. The cursor only moves once your hand is "engaged" (for example an open palm or a pinch-hold).
2. **Smoothing.** A One-Euro filter plus velocity-dependent gain, with a stable-to-fast slider.
3. **Auto-pause** when the real mouse or trackpad moves, during video calls, and when no hand has been seen for a while.
4. **The halo cursor overlay.** A ring under the pointer that shrinks as the pinch closes, as in TouchFree. It's the product's identity, and it also tells the user when a click will fire.
5. **A small gesture set.** About four gestures: move, click, scroll, and one more (zoom or swipe).
6. **Signed and notarised**, with an onboarding screen that asks for Camera and Accessibility permission.
7. **Privacy:** everything stays on-device, a visible "camera on" indicator, and pausing is easy.

### 4.2 Later, not in the MVP
- True touch screen (Sistine-style mirror clip).
- Throw to iPhone, and the iPhone companion app (Multipeer).
- Android TV, with the phone as the camera.
- Custom gesture training and per-app bindings.
- Mac App Store version.

---

## Sources

**Competitors and apps**
- [Pawvis on Product Hunt](https://www.producthunt.com/posts/pawvis) · [Trendshift](https://trendshift.io/repositories/176281)
- [Airpoint on Product Hunt](https://www.producthunt.com/posts/airpoint) · [Airpoint Open SDK](https://www.producthunt.com/products/airpoint/launches/airpoint-open-sdk)
- [Gstrl](https://tomyang-tz.github.io/Gstrl)
- [ControlAir on MacRumors](https://forums.macrumors.com/threads/controlair-app-brings-finger-gesture-controls-to-mac.1844634) · [Flutter on MacStories](https://www.macstories.net/mac/gain-magical-control-over-your-music-player-with-flutter/)
- [Winq](https://chatgate.ai/post/winq)
- [small-cactus/handTrack](https://github.com/small-cactus/handTrack) · [Kazuhito00/simple-virtual-mouse](https://github.com/Kazuhito00/simple-virtual-mouse-using-mediapipe) · [DedoMouse](https://achimmihca.github.io/DedoMouse) · [Handroller](https://github.com/ozankaraali/Handroller)

**Accessibility (head and face control)**
- [macOS Head Pointer (thoughtbot)](https://thoughtbot.com/blog/an-introduction-to-macos-head-pointer)
- [Project Gameface](https://developers.googleblog.com/en/project-gameface-launches-on-android/)

**Hardware**
- [Ultraleap downloads](https://www.ultraleap.com/downloads/leap-motion-controller-2) · [UploadVR: Ultraleap selling Leap Motion](https://www.uploadvr.com/ultraleap-selling-leap-motion-amid-layoffs/) · [Sifted](https://sifted.eu/articles/tencent-ultraleap-sold-for-parts-news) · [VRARWiki](https://vrarwiki.com/wiki/Ultraleap)
- [AirBar review (Laptop Mag)](https://laptopmag.com/reviews/accessories/airbar) · [TIME](https://time.com/4852395/neonode-airbar-mac-review/)

**Research**
- [Project Sistine](https://anishathalye.com/macbook-touchscreen/)
- [UW AirLink](https://ubicomplab.cs.washington.edu/publications/airlink)

**Gesture transfer**
- [GSMArena: Huawei gesture transfer](https://www.gsmarena.com/huawei_demoes_gestureoperated__file_transfer_between_devices-news-65475.php) · [HuaweiCentral](https://www.huaweicentral.com/huawei-may-soon-rollout-air-gesture-file-transfer-feature-to-more-devices/) · [Pura X conflict](https://www.huaweicentral.com/huawei-responds-to-air-gesture-file-transfer-issues-in-pura-x-foldable/)
- [MacRumors NameDrop guide](https://www.macrumors.com/guide/ios-17-airdrop)
- [Magic File Transfer](https://www.producthunt.com/products/magic-file-transfer-fadlan-send/reviews)

**TV control**
- [Samsung Gesture Interaction](https://www.samsung.com/in/support/tv-audio-video/control-your-samsung-tv-with-gesture-interaction) · [Samsung Universal Gestures](https://www.samsung.com/uk/support/tv-audio-video/how-to-use-universal-gestures-on-your-2025-samsung-smart-tv/) · [SamMobile](https://www.sammobile.com/news/do-you-need-a-camera-to-control-your-samsung-tv-with-hand-gestures/)
- [WowMouse (TechPP)](https://techpp.com/2025/07/03/wowmouse-control-your-smart-tv-with-your-smartwatch/)
- [TD Commons smart-TV paper](https://www.tdcommons.org/dpubs_series/10140)

**Usability (jitter, fatigue)**
- [York U jitter study](https://www.yorku.ca/mack/3dui2009.html)
- [LaValle on gorilla arm](https://lavalle.pl/vr/node325.html)
- [XREAL gesture tips](https://tutorials.xreal.com/docs/glasses/one-series/gesture/tips-and-precautions)

**Mac App Store / sandbox**
- [Apple forums thread 789896](https://developer.apple.com/forums/thread/789896) · [thread 820594](https://developer.apple.com/forums/thread/820594) · [thread 780722](https://developer.apple.com/forums/thread/780722)

**Trademarks**
- AirTouch: [aggregator](https://markinton.com/trademark/airtouch-97845440) · [Polyaire app](https://apps.apple.com/app/id1592948163) · [BLUETAG gesture app](https://apkcombo.com/airtouch-gesture-control/com.bluetag.airtouch/)
- AirTrack: [Barcodes LLC](https://trademark.justia.com/976/71/airtrack-97671368.html) · [LEVATA](https://trademarks.justia.com/866/81/airtrack-86681190.html)
- AirPoint: [Magnima](https://trademark.justia.com/887/61/airpoint-88761267.html)
- TrackPoint: [registration](https://markinton.com/trademark/trackpoint-74351853) · [Lenovo trademark list](https://lenovo.com/ca/en/legal/copytrade)
- Alternatives: [Hoverly](https://markinton.com/trademark/hoverly-90487526) · [Skyhand](https://markinton.com/trademark/skyhand-98583328)

**Second round (2026-11-15)**
- [Airpoint](https://www.airpoint.app/) · [Airpoint summary](https://chatgate.ai/post/airpoint) · [Airpoint CLI skill](https://skills.lc/panlm/awesome-skills-deepdive/panlm-awesome-skills-deepdive-productivity-tasks-airpoint-skill-md)
- [Pawvis GitHub](https://github.com/alexandriax/pawvis) · [pawvis.app](https://pawvis.app/) · [Pawvis Product Hunt](https://www.producthunt.com/products/pawvis)
- [AirTouch](https://airtouchapp.com/) · [AirTouch Product Hunt](https://www.producthunt.com/products/airtouch)
- [Air Control](https://github.com/pathakcodes/air-control) · [Conductor](https://github.com/dev-talix/conductor) · [Cenno](https://github.com/sapucaialuann/cenno) · [halo](https://github.com/off9rid/halo) · [gesture-mac](https://github.com/Dheeraj-Baghel/gesture-mac)
- [Spatial Touch (App Store)](https://apps.apple.com/us/app/-/id6737378336)
- [TouchFree interactions](https://docs.ultraleap.com/TouchFree/touchless-interfaces/interactions.html) · [TouchFree UI components](https://docs.ultraleap.com/TouchFree/touchless-interfaces/ui-components.html) · [TouchFree hover states](https://docs.ultraleap.com/TouchFree/touchless-interfaces/hover-states.html)
- [AirTouch for Spectacles (Devpost)](https://devpost.com/software/airtouch-qjz8bm)
- [Vision Pro designer critique](https://itsgoofy.blogspot.com/2026/05/apple-vision-pro-at-2-product-designers.html) · [Gaze and pinch principles](https://medium.com/antaeus-ar/design-principles-issues-for-gaze-and-pinch-interaction-a95e251169ae)
- [HarmonyOS Grab & drop](https://harmonyos.cool/en/docs/gesture/cross-device-air-transfer) · [Gesture Drop](https://github.com/kiranbk0625/gesture-drop-Innovation) · [Hoccer](https://techzoom.org/hoccer-fun-use-slide-throw-gestures-to-transfer-files-between-iphone-android-and-computer/)
- [Watch-based TV control (BGR)](https://bgr.com/2200464/control-smart-tv-with-smartwatch-gestures/)
