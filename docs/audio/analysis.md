# Deriving the ship and swarm sounds

Both engine sounds in this project are **synthesised**, not sampled. Their
parameters come from FFT analysis of reference recordings, so the sound
responds continuously to throttle and swarm size in a way a looping sample
cannot.

No audio asset from Elite Dangerous is included in this repository. The
recordings were analysed to extract frequencies and levels; the synthesis is
original.

## Method

A compilation of isolated Thargoid recordings was decoded to mono at 48 kHz
and analysed with 8192-point Hann windows at eighth-second hops. Frames
quieter than -22 dBFS were discarded as silence between clips. Each surviving
frame was normalised to its own peak **before** being averaged, so a loud clip
does not outweigh a quiet one, and the average was taken across all 1278 loud
frames in the file.

Averaging across many separate clips is what makes the result trustworthy.
Whatever a single clip happens to contain -- a particular screech, a
particular Doppler shift -- averages down. Only what the Thargoid resonates at
*every* time it makes a noise survives the average. A single-window
measurement cannot distinguish the two, and the correction recorded at the
bottom of this page is what happens when it is not distinguished.

## The Thargoid's resonances

| Frequency | Level | Ratio to lowest |
|---|---|---|
| 93.8 Hz | -1.2 dB | 1.00 |
| 175.8 Hz | -5.6 dB | 1.87 |
| 246.1 Hz | 0.0 dB | 2.62 |
| 269.5 Hz | -0.2 dB | 2.87 |
| 310.5 Hz | -5.1 dB | 3.31 |
| 386.7 Hz | -7.9 dB | 4.12 |
| 421.9 Hz | -6.1 dB | 4.50 |
| 468.8 Hz | -5.2 dB | 5.00 |
| 527.3 Hz | -13.4 dB | 5.62 |
| 615.2 Hz | -14.7 dB | 6.56 |
| 662.1 Hz | -15.7 dB | 7.06 |
| 703.1 Hz | -11.9 dB | 7.50 |
| 738.3 Hz | -8.8 dB | 7.87 |
| 820.3 Hz | -14.8 dB | 8.75 |
| 937.5 Hz | -16.3 dB | 10.00 |
| 978.5 Hz | -13.6 dB | 10.44 |
| 1048.8 Hz | -16.4 dB | 11.19 |

Above roughly 1.2 kHz the averaged spectrum flattens to a dense band with no
peaks standing clear of their neighbours. That is broadband content rather
than resonance, and nothing above that point is modelled.

Three findings shaped the synthesis.

**The ratios are not a harmonic series.** 1 : 1.87 : 2.62 : 2.87 : 3.31 :
4.50 : 5.00, where a harmonic series would be 1 : 2 : 3 : 4. Inharmonic
spacing like this is the signature of a resonating shell -- a bell rather than
a pipe. It is the whole character of the sound, and rounding it onto a series
would destroy it. This also matches the fiction: a Thargoid ship is grown
rather than built, so it has no cylinders and no firing rate, and nothing in
it should imply combustion.

**The two loudest resonances sit 23 Hz apart.** 246.1 Hz and 269.5 Hz are
within 0.2 dB of each other and close enough to beat, so the pair roughens on
its own at 23 Hz without any modulation being applied. The texture of the
sound comes from there; nothing needs to be added for it.

**There is no usable modulation measurement.** The source contains discrete
events -- screeches, hyperdictions, weapon fire -- rather than a sustained
engine loop, so the amplitude envelope measures the shape of individual clips
rather than any property of the drive. No throb or tremolo is therefore
modelled on the Matriarch at all. See the limitation noted below.

## The Thargon swarm

The swarm is built from the **same table**, shifted up by a factor of 2.1,
with the two lowest resonances dropped rather than reproduced.

This is an inference rather than a measurement, and it is recorded as one. A
Thargon is the same species grown from the same material, so it should share
the intervals; it is a fraction of the size, and small resonators ring high.
Shifting the measured set is a more defensible way to derive a related sound
than measuring a swarm recording in which dozens of overlapping drives, heavy
Doppler shift and weapon fire cannot be separated.

A 35 Hz amplitude modulation is applied, shallow. Some flutter is what makes
the sound read as many small drives rather than one large one, but at any
depth it chops the tone into a buzz.

## Two corrections worth recording

Both are recorded because each one produced a plausible, confident, wrong
result, and neither was detectable from the numbers alone.

**The bin-width artefact.** An early pass used exported spectrum text files
rather than analysing audio. Every peak in those landed on an exact multiple
of 46.875 Hz, which looked like a clean harmonic series and was modelled as
one. 46.875 Hz was the FFT bin width. The apparent harmonic structure was an
artefact of the analysis resolution, not a property of the sound.

**The wrong ship.** The pass after that measured a four-second window of a
Thargoid encounter and found 87.9 Hz and 46.9 Hz to be the two strongest
components, making them the foundation of the Matriarch's engine. Neither
appears anywhere in the clean source. They were the **human ship** sharing the
frame -- audible in the reference as a low rumble under the Thargoid -- and
a pair of close, non-harmonic low tones under a slow swell is, structurally,
what a diesel engine at idle sounds like. The synthesised result was
recognisably a bus rather than a starship.

The general lesson is the same in both cases: a measurement of the wrong
thing is indistinguishable from a measurement of the right thing until it is
cross-checked against a second source.

## Known limitation

No clean recording of a sustained Thargoid engine loop was found. The source
used here contains isolated events, so the resonances are well supported by
measurement but the *behaviour* of the drive -- how it glides with speed, and
that it cuts out entirely below a threshold rather than idling -- is designed
by ear against the reference, not measured.

The nearest everyday approximation used as a check during tuning was the whine
a bus transmission makes while decelerating: a clear tone that glides
continuously with speed over very little low end. Not a referent, but a useful
test -- if the result sounds like an engine idling rather than a gearbox
gliding, it is wrong.

## Reproducing this

The analysis scripts are not checked in -- they are throwaway tooling -- but
the method above is enough to repeat it. The synthesis parameters live in:

- `godot/scripts/audio/engine_hum.gd`
- `godot/scripts/audio/swarm_roar.gd`
- `godot/scripts/audio/tone_bank.gd` -- the shared rendering

Each frequency and level in the first two traces to a row in the table above.
