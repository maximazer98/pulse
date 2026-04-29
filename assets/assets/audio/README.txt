Drop folgende WAV-Dateien hier rein (kurze SFX, 16-bit PCM):

- pass.wav     ~80ms, weicher Blip, neutraler Pass-Sound
- close.wav    ~150ms, Close-Call-Akzent (heller, mit Zischen)
- gameover.wav ~400ms, Crash/Boom

Quellen: freesound.org, opengameart.org, oder selbst per sfxr/bfxr/jsfxr generieren
(https://sfxr.me/ — generiert im Browser und lädt als WAV).

Das Spiel funktioniert ohne diese Dateien (silent fallback) — sobald vorhanden,
werden sie automatisch geladen.
