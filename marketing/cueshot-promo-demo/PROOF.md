# CueShot Promo Demo Proof

## Output

- Final video: `../../docs/media/cueshot-promo-demo.mp4`
- README preview: `../../docs/media/cueshot-promo-preview.gif`
- Poster: `../../docs/media/cueshot-promo-poster.png`
- Local silent render and proof frames: `proof/` (ignored from source control)
- Source composition: `index.html`
- Storyboard: `storyboard.md`
- Audio script: `assets/audio/voiceover.txt`
- Privacy posture: video UI is coded HTML/CSS; no real desktop screenshots are used in the composition.
- Element-selection scenario: coded Product Settings mock UI with the exact highlight attached to the selected toggle.

## Render Specs

- Duration: 36.000 seconds
- Video: H.264, 1920 x 1080, 30 fps, BT.709
- Audio: AAC, 96 kHz stereo, ElevenLabs young American voiceover/music/SFX mix
- File size: 8,557,890 bytes
- Audio levels: mean -20.8 dB, max -0.9 dB

## Verification

```bash
npm run check
ffprobe -v error -show_entries format=duration,size,bit_rate -show_streams -of json ../../docs/media/cueshot-promo-demo.mp4
ffmpeg -v error -i ../../docs/media/cueshot-promo-demo.mp4 -f null -
ffmpeg -i ../../docs/media/cueshot-promo-demo.mp4 -af volumedetect -f null -
```

`npm run check` passed with no errors. HyperFrames reported the expected `gsap_studio_edit_blocked` warning because the composition intentionally animates positions through GSAP, plus a maintainability warning that the single HTML composition is large.

## Audio Status

The final cut was produced with:

- `assets/audio/voiceover-elevenlabs.mp3`
- `assets/audio/music-elevenlabs.mp3`
- `assets/audio/sfx-click-elevenlabs.mp3`
- `assets/audio/sfx-reticle-elevenlabs.mp3`
- `assets/audio/sfx-whoosh-elevenlabs.mp3`
- `assets/audio/sfx-element-lock-elevenlabs.mp3`
- `assets/audio/cueshot-promo-elevenlabs-mix.m4a`

The local Python sound-effects helper hit a certificate verification issue, so `scripts/generate-elevenlabs-audio.sh` now generates sound effects through direct ElevenLabs API `curl` calls.

Raw generated audio is ignored from source control. Regenerate it locally with an ElevenLabs API key when updating the promo video.

To regenerate production audio:

```bash
zsh -ic './scripts/generate-elevenlabs-audio.sh'
ffmpeg -y -i proof/cueshot-promo-demo-silent.mp4 -i assets/audio/cueshot-promo-elevenlabs-mix.m4a -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -shortest ../../docs/media/cueshot-promo-demo.mp4
```

The ElevenLabs script uses the staged voiceover copy, music direction, and premium UI click, reticle, whoosh, and element-lock sound-effect prompts.
