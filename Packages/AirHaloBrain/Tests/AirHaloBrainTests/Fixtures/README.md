# Recorded hand sessions

Put recordings from the app's Debug window here (⏺ Record, then "Reveal in Finder").

To make one a test, open the JSON and add an `expect` object, for example:

```json
"expect": { "leftClicks": 1, "drags": 0 }
```

or, for a resting hand that must never do anything:

```json
"expect": { "noCommands": true }
```

`make test` replays every recording here through the brain and checks the expectations.
Fields you leave out aren't checked. A port of the brain in another language can replay
the same files to prove it behaves the same.
