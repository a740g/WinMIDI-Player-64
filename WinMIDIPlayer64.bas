'-----------------------------------------------------------------------------------------------------------------------
' QB64-PE Windows MIDI Player
' Copyright (c) 2023 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'include/ColorOps.bi'
'$INCLUDE:'include/FileOps.bi'
'$INCLUDE:'include/StringOps.bi'
'$INCLUDE:'include/Base64.bi'
'$INCLUDE:'include/ImGUI.bi'
'$INCLUDE:'include/WinMIDIPlayer.bi'
'$INCLUDE:'compactcassette.png.bi'
'$INCLUDE:'raindrop.wav.bi'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
$NOPREFIX
$RESIZE:SMOOTH
$EXEICON:'./WinMIDIPlayer64.ico'
$VERSIONINFO:CompanyName=Samuel Gomes
$VERSIONINFO:FileDescription=WinMIDI Player 64 executable
$VERSIONINFO:InternalName=WinMIDIPlayer64
$VERSIONINFO:LegalCopyright=Copyright (c) 2023, Samuel Gomes
$VERSIONINFO:LegalTrademarks=All trademarks are property of their respective owners
$VERSIONINFO:OriginalFilename=WinMIDIPlayer64.exe
$VERSIONINFO:ProductName=WinMIDI Player 64
$VERSIONINFO:Web=https://github.com/a740g
$VERSIONINFO:Comments=https://github.com/a740g
$VERSIONINFO:FILEVERSION#=2,0,1,0
$VERSIONINFO:PRODUCTVERSION#=2,0,1,0
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
CONST APP_NAME = "WinMIDI Player 64"
CONST FRAME_RATE_MAX = 60
' Program events
CONST EVENT_NONE = 0 ' idle
CONST EVENT_QUIT = 1 ' user wants to quit
CONST EVENT_CMDS = 2 ' process command line
CONST EVENT_LOAD = 3 ' user want to load files
CONST EVENT_DROP = 4 ' user dropped files
CONST EVENT_PLAY = 5 ' play next song
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' USER DEFINED TYPES
'-----------------------------------------------------------------------------------------------------------------------
TYPE UIType ' bunch of UI widgets to change stuff
    cmdOpen AS LONG ' open dialog box button
    cmdPlayPause AS LONG ' play / pause button
    cmdNext AS LONG ' next tune button
    cmdIncVolume AS LONG ' increase volume button
    cmdDecVolume AS LONG ' decrease volume button
    cmdRepeat AS LONG ' repeat enable / disable button
    cmdAbout AS LONG ' shows an about dialog
END TYPE
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------------------------
DIM SHARED MIDIVolume AS SINGLE ' global MIDI volume
DIM SHARED ElapsedTicks AS UNSIGNED INTEGER64 ' amount of time spent in playing the current tune
DIM SHARED TuneTitle AS STRING '  tune title
DIM SHARED BackgroundImage AS LONG ' the CC image that we will use for the background
DIM SHARED UI AS UIType ' user interface controls
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
InitProgram

DIM event AS BYTE: event = EVENT_CMDS ' default to command line event first

' Main loop
DO
    SELECT CASE event
        CASE EVENT_QUIT
            EXIT DO

        CASE EVENT_DROP
            event = ProcessDroppedFiles

        CASE EVENT_LOAD
            event = OnSelectedFiles

        CASE EVENT_CMDS
            event = OnCommandLine

        CASE ELSE
            event = OnWelcomeScreen
    END SELECT
LOOP UNTIL event = EVENT_QUIT

AUTODISPLAY
WidgetFreeAll
FREEIMAGE BackgroundImage
SYSTEM
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------------------------
' Initializes everything we need
SUB InitProgram
    CONST BUTTON_WIDTH = 48 ' default button width
    CONST BUTTON_HEIGHT = 24 ' default button height
    CONST BUTTON_GAP = 4 ' default gap between buttons
    CONST BUTTON_Y = 172 ' default button top

    SCREEN NEWIMAGE(320, 200, 32) ' like SCREEN 13 but in 32bpp
    TITLE APP_NAME ' set default app title
    CHDIR STARTDIR$ ' change to the directory specifed by the environment
    ACCEPTFILEDROP ' enable drag and drop of files
    ALLOWFULLSCREEN SQUAREPIXELS , SMOOTH ' allow the user to press Alt+Enter to go fullscreen
    DISPLAYORDER HARDWARE , HARDWARE1 , GLRENDER , SOFTWARE ' draw the software stuff + text at the end
    FONT 8 ' use 8x8 font by default
    PRINTMODE KEEPBACKGROUND ' set text rendering to preserve backgroud
    ' Next 2 lines load the background, decodes, decompresses and loads it from memory to an image
    RESTORE Data_compactcassette_png_46482
    BackgroundImage = LOADIMAGE(LoadResource, 33, "memory")
    MIDIVolume = 1 ' set initial volume at 100%

    DIM buttonX AS LONG: buttonX = 32 ' this is where we will start
    UI.cmdOpen = PushButtonNew("Open", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, FALSE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdPlayPause = PushButtonNew("Play", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, TRUE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdNext = PushButtonNew("Next", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, FALSE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdRepeat = PushButtonNew("Loop", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, TRUE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdAbout = PushButtonNew("About", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, FALSE)
    UI.cmdDecVolume = PushButtonNew("-V", 102, 124, BUTTON_HEIGHT, BUTTON_HEIGHT, FALSE)
    UI.cmdIncVolume = PushButtonNew("+V", 192, 124, BUTTON_HEIGHT, BUTTON_HEIGHT, FALSE)

    DISPLAY ' only swap display buffer when we want
END SUB


' Weird plasma effect
SUB DrawWeirdPlasma
    CONST DIVIDER = 4

    STATIC t AS LONG

    DIM buffer AS LONG: buffer = NEWIMAGE(WIDTH \ DIVIDER, HEIGHT \ DIVIDER, 32)
    DIM memBuffer AS MEM: memBuffer = MEMIMAGE(buffer)
    DIM W AS LONG: W = WIDTH(buffer)
    DIM H AS LONG: H = HEIGHT(buffer)
    DIM right AS LONG: right = W - 1
    DIM bottom AS LONG: bottom = H - 1

    DIM AS LONG x, y
    DIM AS SINGLE r, g, b, r2, g2, b2

    FOR y = 0 TO bottom
        FOR x = 0 TO right
            r = 128! + 127! * SIN(x / 16! - t / 20!)
            g = 128! + 127! * SIN(y / 16! - t / 22!)
            b = 128! + 127! * SIN((x + y) / 32! - t / 24!)
            r2 = 128! + 127! * SIN(y / 32! + t / 26!)
            g2 = 128! + 127! * SIN(x / 32! + t / 28!)
            b2 = 128! + 127! * SIN((x - y) / 32! + t / 30!)

            _MEMPUT memBuffer, memBuffer.OFFSET + (4 * W * y) + x * 4, ToBGRA((r + r2) / 2!, (g + g2) / 2!, (b + b2) / 2!, 255) AS _UNSIGNED LONG
        NEXT
    NEXT

    DIM bufferGPU AS LONG: bufferGPU = COPYIMAGE(buffer, 33)
    PUTIMAGE , bufferGPU
    FREEIMAGE bufferGPU
    MEMFREE memBuffer
    FREEIMAGE buffer

    t = t + 1
END SUB


' Draws one cassette reel
SUB DrawReel (x AS LONG, y AS LONG, c AS UNSIGNED LONG, a AS SINGLE)
    STATIC drawCmds AS STRING, clr AS UNSIGNED LONG
    STATIC AS LONG angle, xp, yp

    ' These must be copied to static variables for VARPTR$ to work correctly
    angle = a
    xp = x
    yp = y
    clr = c

    ' We'll setup the DRAW commands just once to a STATIC string
    IF LEN(drawCmds) = 0 THEN drawCmds = "C=" + VARPTR$(clr) + "BM=" + VARPTR$(xp) + ",=" + VARPTR$(yp) + "TA=" + VARPTR$(angle) + "BU17L1D5R1U5"

    ' Faster with unrolled loop
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    CIRCLE (xp, yp), 18, clr
END SUB


' Draws both reels at correct locations and manages rotation
SUB DrawReels
    STATIC angle AS UNSIGNED LONG

    DrawReel 95, 92, BGRA_WHITE, angle
    DrawReel 223, 92, BGRA_WHITE, angle

    IF NOT MIDI_IsPaused THEN angle = angle + 1
END SUB


' Draws a frame around the CC
SUB DrawFrame
    CONST FRAME_COLOR = RGBA32(0, 0, 0, 128)

    LINE (0, 0)-(319, 23), FRAME_COLOR, BF
    LINE (0, 167)-(319, 199), FRAME_COLOR, BF
    LINE (0, 24)-(31, 166), FRAME_COLOR, BF
    LINE (287, 24)-(319, 166), FRAME_COLOR, BF
END SUB


' This draws everything to the screen
SUB DrawScreen
    CLS , 0 ' clear screen with black with no alpha
    DrawWeirdPlasma
    PUTIMAGE , BackgroundImage
    DrawReels
    DrawFrame

    DIM text AS STRING: text = LEFT$(TuneTitle, 28)
    FONT 14
    COLOR BGRA_BLACK
    LOCATE 4, 7 + (14 - LEN(text) \ 2)
    PRINT text;

    DIM minute AS UNSIGNED LONG: minute = ElapsedTicks \ 60000
    DIM second AS UNSIGNED LONG: second = (ElapsedTicks MOD 60000) \ 1000
    COLOR BGRA_WHITE
    LOCATE 7, 18
    PRINT RIGHT$("00" + LTRIM$(STR$(minute)), 3); ":"; RIGHT$("00" + LTRIM$(STR$(second)), 2);

    FONT 16
    COLOR BGRA_BLACK
    LOCATE 9, 19
    PRINT RIGHT$("  " + LTRIM$(STR$(ROUND(MIDIVolume * 100))), 3); "%";

    FONT 8
    LOCATE 14, 20
    IF MIDI_IsPaused THEN
        COLOR BGRA_ORANGERED
        PRINT STRING$(2, 179);
    ELSE
        COLOR BGRA_YELLOW
        PRINT STRING$(2, 16);
    END IF

    WidgetDisabled UI.cmdPlayPause, LEN(TuneTitle) = 0
    WidgetDisabled UI.cmdNext, LEN(TuneTitle) = 0
    WidgetDisabled UI.cmdRepeat, LEN(TuneTitle) = 0
    PushButtonDepressed UI.cmdPlayPause, NOT MIDI_IsPaused AND LEN(TuneTitle) <> 0
    PushButtonDepressed UI.cmdRepeat, MIDI_IsLooping

    WidgetUpdate ' draw widgets above everything else. This also fetches input

    DISPLAY ' flip the framebuffer
END SUB


' Shows the About dialog box
SUB ShowAboutDialog
    DIM tunePaused AS BYTE

    IF MIDI_IsPlaying AND NOT MIDI_IsPaused THEN
        MIDI_Pause TRUE
        tunePaused = TRUE
    END IF

    RESTORE Data_raindrop_wav_482216
    Sound_PlayFromMemory LoadResource, TRUE

    MessageBox APP_NAME, APP_NAME + String$(2, KEY_ENTER) + _
        "Syntax: WinMIDIPlayer64 [-?] [midifile1.mid] [midifile2.mid] ..." + Chr$(KEY_ENTER) + _
        "    -?: Shows this message" + String$(2, KEY_ENTER) + _
        "Copyright (c) 2023, Samuel Gomes" + String$(2, KEY_ENTER) + _
        "https://github.com/a740g/", "info"

    Sound_Stop

    IF tunePaused THEN MIDI_Pause FALSE
END SUB


' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
FUNCTION OnPlayMIDITune%% (fileName AS STRING)
    SHARED InputManager AS InputManagerType

    OnPlayMIDITune = EVENT_PLAY ' default event is to play next song
    DIM AS UNSIGNED INTEGER64 currentTick, lastTick

    lastTick = GetTicks

    IF NOT MIDI_PlayFromFile(fileName) THEN ' We want the MIDI file to loop just once
        MESSAGEBOX APP_NAME, "Failed to load: " + fileName, "error"
        EXIT FUNCTION
    END IF

    ' Set the app title to display the file name
    TuneTitle = GetFileNameFromPathOrURL(fileName)
    TITLE TuneTitle + " - " + APP_NAME ' show complete filename in the title
    TuneTitle = LEFT$(TuneTitle, LEN(TuneTitle) - LEN(GetFileExtensionFromPathOrURL(TuneTitle))) ' get the file name without the extension

    MIDI_SetVolume MIDIVolume ' set the volume as Windows will reset the volume for new MIDI streams

    DO
        currentTick = GetTicks
        IF currentTick > lastTick AND NOT MIDI_IsPaused THEN ElapsedTicks = ElapsedTicks + (currentTick - lastTick)
        lastTick = currentTick

        DrawScreen

        IF WidgetClicked(UI.cmdNext) OR InputManager.keyCode = KEY_ESCAPE OR InputManager.keyCode = KEY_UPPER_N OR InputManager.keyCode = KEY_LOWER_N THEN
            EXIT DO

        ELSEIF TOTALDROPPEDFILES > 0 THEN
            OnPlayMIDITune = EVENT_DROP
            EXIT DO

        ELSEIF WidgetClicked(UI.cmdOpen) OR InputManager.keyCode = KEY_UPPER_O OR InputManager.keyCode = KEY_LOWER_O THEN
            OnPlayMIDITune = EVENT_LOAD
            EXIT DO

        ELSEIF WidgetClicked(UI.cmdPlayPause) OR InputManager.keyCode = KEY_UPPER_P OR InputManager.keyCode = KEY_LOWER_P THEN
            MIDI_Pause NOT MIDI_IsPaused

        ELSEIF WidgetClicked(UI.cmdRepeat) OR InputManager.keyCode = KEY_UPPER_L OR InputManager.keyCode = KEY_LOWER_L THEN
            MIDI_Loop NOT MIDI_IsLooping

        ELSEIF WidgetClicked(UI.cmdIncVolume) OR InputManager.keyCode = KEY_PLUS OR InputManager.keyCode = KEY_EQUALS THEN
            MIDIVolume = MIDIVolume + 0.01
            MIDI_SetVolume MIDIVolume
            MIDIVolume = MIDI_GetVolume

        ELSEIF WidgetClicked(UI.cmdDecVolume) OR InputManager.keyCode = KEY_MINUS OR InputManager.keyCode = KEY_UNDERSCORE THEN
            MIDIVolume = MIDIVolume - 0.01
            MIDI_SetVolume MIDIVolume
            MIDIVolume = MIDI_GetVolume

        ELSEIF WidgetClicked(UI.cmdAbout) THEN
            ShowAboutDialog

        ELSEIF InputManager.keyCode = 21248 THEN ' shift + delete - you know what this does :)
            IF MESSAGEBOX(APP_NAME, "Are you sure you want to delete " + fileName + " permanently?", "yesno", "question", 0) = 1 THEN
                KILL fileName
                EXIT DO
            END IF

        END IF

        LIMIT FRAME_RATE_MAX
    LOOP UNTIL NOT MIDI_IsPlaying

    MIDI_Stop

    ' Clear these so that we do not keep showing dead info
    TuneTitle = EMPTY_STRING
    ElapsedTicks = NULL

    TITLE APP_NAME ' set app title to the way it was
END FUNCTION


' Welcome screen loop
FUNCTION OnWelcomeScreen%%
    SHARED InputManager AS InputManagerType

    DIM e AS BYTE: e = EVENT_NONE

    DO
        DrawScreen

        IF InputManager.keyCode = KEY_ESCAPE THEN
            e = EVENT_QUIT

        ELSEIF TOTALDROPPEDFILES > 0 THEN
            e = EVENT_DROP

        ELSEIF WidgetClicked(UI.cmdOpen) OR InputManager.keyCode = KEY_UPPER_O OR InputManager.keyCode = KEY_LOWER_O THEN
            e = EVENT_LOAD

        ELSEIF WidgetClicked(UI.cmdIncVolume) OR InputManager.keyCode = KEY_PLUS OR InputManager.keyCode = KEY_EQUALS THEN
            MIDIVolume = MIDIVolume + 0.01
            IF MIDIVolume > 1 THEN MIDIVolume = 1

        ELSEIF WidgetClicked(UI.cmdDecVolume) OR InputManager.keyCode = KEY_MINUS OR InputManager.keyCode = KEY_UNDERSCORE THEN
            MIDIVolume = MIDIVolume - 0.01
            IF MIDIVolume < 0 THEN MIDIVolume = 0

        ELSEIF WidgetClicked(UI.cmdAbout) THEN
            ShowAboutDialog

        END IF

        LIMIT FRAME_RATE_MAX
    LOOP WHILE e = EVENT_NONE

    OnWelcomeScreen = e
END FUNCTION


' Processes the command line one file at a time
FUNCTION OnCommandLine%%
    DIM e AS BYTE: e = EVENT_NONE

    IF GetProgramArgumentIndex(KEY_QUESTION_MARK) > 0 THEN
        ShowAboutDialog
        e = EVENT_QUIT
    ELSE
        DIM i AS LONG: FOR i = 1 TO COMMANDCOUNT
            e = OnPlayMIDITune(COMMAND$(i))
            IF e <> EVENT_PLAY THEN EXIT FOR
        NEXT
    END IF

    OnCommandLine = e
END FUNCTION


' Processes dropped files one file at a time
FUNCTION ProcessDroppedFiles%%
    ' Make a copy of the dropped file and clear the list
    REDIM fileNames(1 TO TOTALDROPPEDFILES) AS STRING

    DIM e AS BYTE: e = EVENT_NONE

    DIM i AS LONG: FOR i = 1 TO TOTALDROPPEDFILES
        fileNames(i) = DROPPEDFILE(i)
    NEXT
    FINISHDROP ' This is critical

    ' Now play the dropped file one at a time
    FOR i = LBOUND(fileNames) TO UBOUND(fileNames)
        e = OnPlayMIDITune(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT FOR
    NEXT

    ProcessDroppedFiles = e
END FUNCTION


' Processes a list of files selected by the user
FUNCTION OnSelectedFiles%%
    DIM ofdList AS STRING
    DIM e AS BYTE: e = EVENT_NONE

    ofdList = OPENFILEDIALOG$(APP_NAME, , "*.mid|*.MID|*.Mid|*.midi|*.MIDI|*.Midi", "Standard MIDI Files", TRUE)

    IF ofdList = EMPTY_STRING THEN EXIT FUNCTION

    REDIM fileNames(0 TO 0) AS STRING

    DIM j AS LONG: j = TokenizeString(ofdList, "|", EMPTY_STRING, FALSE, fileNames())

    DIM i AS LONG: FOR i = 0 TO j - 1
        e = OnPlayMIDITune(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT FOR
    NEXT

    OnSelectedFiles = e
END FUNCTION
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'include/ProgramArgs.bas'
'$INCLUDE:'include/ColorOps.bas'
'$INCLUDE:'include/FileOps.bas'
'$INCLUDE:'include/StringOps.bas'
'$INCLUDE:'include/Base64.bas'
'$INCLUDE:'include/ImGUI.bas'
'$INCLUDE:'include/WinMIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------
