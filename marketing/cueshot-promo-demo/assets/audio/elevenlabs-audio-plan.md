# ElevenLabs Audio Plan

The checked-in promo render uses ElevenLabs-generated voiceover, music, and sound effects. The generation command loads `ELEVENLABS_API_KEY` from the environment; in Edgar's local shell this may require an interactive zsh invocation.

## Voiceover

- Skill: `text-to-speech`
- Model: `eleven_multilingual_v2`
- Voice: Mark - Natural Conversations (`UgBBYS2sOqTuMpoF3BR0`), young American conversational male
- Script: `voiceover.txt`
- Output: `voiceover-elevenlabs.mp3`

## Music

- Skill: `music`
- Model: `music_v1`
- Duration: 36000 ms
- Instrumental: true
- Prompt: "Restrained premium technology product demo bed for a macOS element-selection workflow, graphite glass mood, subtle analog pulse, soft modular bass, crisp minimal percussion, young and confident but not corporate, clean space for voiceover."
- Output: `music-elevenlabs.mp3`

## Sound Effects

- Skill: `sound-effects`
- Model: `eleven_text_to_sound_v2`
- Prompts:
  - "Premium macOS UI click, soft glass button press, short clean transient"
  - "Subtle digital reticle lock-on chime, premium product UI, short decay"
  - "Soft whoosh focus transition, graphite glass interface, understated"
  - "Precise UI element selection lock, premium reticle snap, short clean confirmation chime"
- Outputs: `sfx-click-elevenlabs.mp3`, `sfx-reticle-elevenlabs.mp3`, `sfx-whoosh-elevenlabs.mp3`, `sfx-element-lock-elevenlabs.mp3`
