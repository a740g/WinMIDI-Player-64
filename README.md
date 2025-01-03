# MIDI PLAYER 64

[MIDI Player 64](https://github.com/a740g/MIDI-Player-64) is a [QB64-PE](https://www.qb64phoenix.com/) compatible MIDI player library built using the [rtmidi](https://github.com/thestk/rtmidi) and [fmidi](https://github.com/jpcima/fmidi) libraries.

![Screenshot 1](screenshots/screenshot1.png)
![Screenshot 2](screenshots/screenshot2.png)

## FEATURES

- Simplified API designed for quick integration into projects.
- Works with both 64-bit and 32-bit versions of QB64-PE.
- No shared library dependencies, offering a simpler setup compared to solutions requiring DLLs.
- Runs on Windows, Linux, and macOS.
- Includes an example to demonstrate library usage.

## USAGE

1. Clone this repository to a directory of your choice:

    ```bash
    git clone https://github.com/a740g/MIDI-Player-64.git
    cd MIDIPlayer64
    ```

2. Initialize the submodules:

    ```bash
    git submodule update --init --recursive
    ```

3. Open `MIDIPlayer64.bas` in the QB64-PE IDE.

4. Press `F5` to compile and run

To use the library in your project, add the [Toolbox64](https://github.com/a740g/Toolbox64) repository as a [Git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

## API

The library provides the following functions and subroutines:

```VB
FUNCTION MIDI_GetErrorMessage$
FUNCTION MIDI_GetPortCount~&
FUNCTION MIDI_GetPortName$ (portIndex AS _UNSIGNED LONG)
FUNCTION MIDI_SetPort%% (portIndex AS _UNSIGNED LONG)
FUNCTION MIDI_GetPort~&
FUNCTION MIDI_PlayFromMemory%% (buffer AS STRING)
SUB MIDI_PlayFromMemory (buffer AS STRING)
FUNCTION MIDI_PlayFromFile%% (fileName AS STRING)
SUB MIDI_PlayFromFile (fileName AS STRING)
SUB MIDI_Stop
FUNCTION MIDI_IsPlaying%%
SUB MIDI_Loop (loops AS LONG)
FUNCTION MIDI_IsLooping%%
SUB MIDI_Pause (state AS _BYTE)
FUNCTION MIDI_IsPaused%%
FUNCTION MIDI_GetTotalTime#
FUNCTION MIDI_GetCurrentTime#
SUB MIDI_SetVolume (volume AS SINGLE)
FUNCTION MIDI_GetVolume!
SUB MIDI_SeekToTime (seekTime AS DOUBLE)
FUNCTION MIDI_GetFormat$
```

## NOTES

- Requires the latest version of [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe/releases/latest)
- When cloning this repository, submodules are not cloned automatically. Run:

    ```bash
    git submodule update --init --recursive
    ```

- This library supports MIDI playback through the system's MIDI output device instead of a software synthesizer.

## ASSETS

- [Icon](https://www.iconarchive.com/artist/grafikartes.html) by [Paulo Freitas](https://behance.net/grafikartes)
