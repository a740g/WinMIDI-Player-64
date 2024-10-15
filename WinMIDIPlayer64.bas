'-----------------------------------------------------------------------------------------------------------------------
' QB64-PE Windows MIDI Player
' Copyright (c) 2024 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'include/GraphicOps.bi'
'$INCLUDE:'include/Pathname.bi'
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
$VERSIONINFO:CompanyName='Samuel Gomes'
$VERSIONINFO:FileDescription='WinMIDI Player 64 executable'
$VERSIONINFO:InternalName='WinMIDIPlayer64'
$VERSIONINFO:LegalCopyright='Copyright (c) 2024, Samuel Gomes'
$VERSIONINFO:LegalTrademarks='All trademarks are property of their respective owners'
$VERSIONINFO:OriginalFilename='WinMIDIPlayer64.exe'
$VERSIONINFO:ProductName='WinMIDI Player 64'
$VERSIONINFO:Web='https://github.com/a740g'
$VERSIONINFO:Comments='https://github.com/a740g'
$VERSIONINFO:FILEVERSION#=2,0,4,0
$VERSIONINFO:PRODUCTVERSION#=2,0,4,0
$EXEICON:'./WinMIDIPlayer64.ico'
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
DIM SHARED ElapsedTicks AS _UNSIGNED _INTEGER64 ' amount of time spent in playing the current tune
DIM SHARED TuneTitle AS STRING '  tune title
DIM SHARED BackgroundImage AS LONG ' the CC image that we will use for the background
DIM SHARED UI AS UIType ' user interface controls
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
InitProgram

DIM event AS _BYTE: event = EVENT_CMDS ' default to command line event first

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

_AUTODISPLAY
WidgetFreeAll
_FREEIMAGE BackgroundImage
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

    $RESIZE:SMOOTH
    SCREEN _NEWIMAGE(320, 200, 32) ' like SCREEN 13 but in 32bpp
    _TITLE APP_NAME ' set default app title
    CHDIR _STARTDIR$ ' change to the directory specifed by the environment
    _ACCEPTFILEDROP ' enable drag and drop of files
    _ALLOWFULLSCREEN _SQUAREPIXELS , _SMOOTH ' allow the user to press Alt+Enter to go fullscreen
    _DISPLAYORDER _HARDWARE , _HARDWARE1 , _GLRENDER , _SOFTWARE ' draw the software stuff + text at the end
    _FONT 8 ' use 8x8 font by default
    _PRINTMODE _KEEPBACKGROUND ' set text rendering to preserve backgroud
    ' Decode, decompress, and load the background from memory to an image
    BackgroundImage = _LOADIMAGE(Base64_LoadResourceString(DATA_COMPACTCASSETTE_PNG_BI_42837, SIZE_COMPACTCASSETTE_PNG_BI_42837, COMP_COMPACTCASSETTE_PNG_BI_42837), 33, "memory")
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

    _DISPLAY ' only swap display buffer when we want
END SUB


' Weird plasma effect
SUB DrawWeirdPlasma
    $CHECKING:OFF

    CONST __WP_DIV = 4

    STATIC AS LONG w, h, t, imgHandle
    STATIC imgMem AS _MEM

    DIM rW AS LONG: rW = _WIDTH \ __WP_DIV
    DIM rH AS LONG: rH = _HEIGHT \ __WP_DIV

    IF w <> rW _ORELSE h <> rH _ORELSE imgHandle >= -1 THEN
        IF imgHandle < -1 THEN
            _FREEIMAGE imgHandle
            _MEMFREE imgMem
        END IF

        imgHandle = _NEWIMAGE(rW, rH, 32)
        imgMem = _MEMIMAGE(imgHandle)
        w = rW
        h = rH
    END IF

    DIM AS LONG x, y
    DIM AS SINGLE r1, g1, b1, r2, g2, b2

    WHILE y < h
        x = 0
        g1 = 128! * SIN(y / 16! - t / 22!)
        r2 = 128! * SIN(y / 32! + t / 26!)

        WHILE x < w
            r1 = 128! * SIN(x / 16! - t / 20!)
            b1 = 128! * SIN((x + y) / 32! - t / 24!)
            g2 = 128! * SIN(x / 32! + t / 28!)
            b2 = 128! * SIN((x - y) / 32! + t / 30!)

            _MEMPUT imgMem, imgMem.OFFSET + (4 * w * y) + x * 4, _RGB32((r1 + r2) / 2!, (g1 + g2) / 2!, (b1 + b2) / 2!) AS _UNSIGNED LONG

            x = x + 1
        WEND

        y = y + 1
    WEND

    DIM imgGPUHandle AS LONG: imgGPUHandle = _COPYIMAGE(imgHandle, 33)
    _PUTIMAGE , imgGPUHandle
    _FREEIMAGE imgGPUHandle

    t = t + 1

    $CHECKING:ON
END SUB


' Draws one cassette reel
SUB DrawReel (x AS LONG, y AS LONG, c AS _UNSIGNED LONG, a AS SINGLE)
    STATIC drawCmds AS STRING, clr AS _UNSIGNED LONG
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
    Graphics_DrawCircle xp, yp, 18, clr
END SUB


' Draws both reels at correct locations and manages rotation
SUB DrawReels
    STATIC angle AS _UNSIGNED LONG

    DrawReel 95, 92, BGRA_WHITE, angle
    DrawReel 223, 92, BGRA_WHITE, angle

    IF NOT MIDI_IsPaused THEN angle = angle + 1
END SUB


' Draws a frame around the CC
SUB DrawFrame
    CONST FRAME_COLOR = _RGBA32(0, 0, 0, 128)

    Graphics_DrawFilledRectangle 0, 0, 319, 23, FRAME_COLOR
    Graphics_DrawFilledRectangle 0, 167, 319, 199, FRAME_COLOR
    Graphics_DrawFilledRectangle 0, 24, 31, 166, FRAME_COLOR
    Graphics_DrawFilledRectangle 287, 24, 319, 166, FRAME_COLOR
END SUB


' This draws everything to the screen
SUB DrawScreen
    CLS , 0 ' clear screen with black with no alpha
    DrawWeirdPlasma
    _PUTIMAGE , BackgroundImage
    DrawReels
    DrawFrame

    DIM text AS STRING: text = LEFT$(TuneTitle, 28)
    _FONT 14
    COLOR BGRA_BLACK
    LOCATE 4, 7 + (14 - LEN(text) \ 2)
    PRINT text;

    DIM minute AS _UNSIGNED LONG: minute = ElapsedTicks \ 60000
    DIM second AS _UNSIGNED LONG: second = (ElapsedTicks MOD 60000) \ 1000
    COLOR BGRA_WHITE
    LOCATE 7, 18
    PRINT RIGHT$("00" + LTRIM$(STR$(minute)), 3); ":"; RIGHT$("00" + LTRIM$(STR$(second)), 2);

    _FONT 16
    COLOR BGRA_BLACK
    LOCATE 9, 19
    PRINT RIGHT$("  " + LTRIM$(STR$(_ROUND(MIDIVolume * 100))), 3); "%";

    _FONT 8
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

    _DISPLAY ' flip the framebuffer
END SUB


' Shows the About dialog box
SUB ShowAboutDialog
    DIM tunePaused AS _BYTE

    IF MIDI_IsPlaying AND NOT MIDI_IsPaused THEN
        MIDI_Pause TRUE
        tunePaused = TRUE
    END IF

    RESTORE data_raindrop_wav_bi_482216
    Sound_PlayFromMemory Base64_LoadResourceData, TRUE

    _MESSAGEBOX APP_NAME, APP_NAME + STRING$(2, KEY_ENTER) + _
        "Syntax: WinMIDIPlayer64 [-?] [midifile1.mid] [midifile2.mid] ..." + CHR$(KEY_ENTER) + _
        "    -?: Shows this message" + STRING$(2, KEY_ENTER) + _
        "Copyright (c) 2024, Samuel Gomes" + STRING$(2, KEY_ENTER) + _
        "https://github.com/a740g/", "info"

    Sound_Stop

    IF tunePaused THEN MIDI_Pause FALSE
END SUB


' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
FUNCTION OnPlayMIDITune%% (fileName AS STRING)
    SHARED InputManager AS InputManagerType

    OnPlayMIDITune = EVENT_PLAY ' default event is to play next song
    DIM AS _UNSIGNED _INTEGER64 currentTick, lastTick

    lastTick = Time_GetTicks

    IF NOT MIDI_PlayFromFile(fileName) THEN ' We want the MIDI file to loop just once
        _MESSAGEBOX APP_NAME, "Failed to load: " + fileName, "error"
        EXIT FUNCTION
    END IF

    ' Set the app title to display the file name
    TuneTitle = Pathname_GetFileName(fileName)
    _TITLE TuneTitle + " - " + APP_NAME ' show complete filename in the title
    TuneTitle = LEFT$(TuneTitle, LEN(TuneTitle) - LEN(Pathname_GetFileExtension(TuneTitle))) ' get the file name without the extension

    MIDI_SetVolume MIDIVolume ' set the volume as Windows will reset the volume for new MIDI streams

    DO
        currentTick = Time_GetTicks
        IF currentTick > lastTick AND NOT MIDI_IsPaused THEN ElapsedTicks = ElapsedTicks + (currentTick - lastTick)
        lastTick = currentTick

        DrawScreen

        IF WidgetClicked(UI.cmdNext) OR InputManager.keyCode = KEY_ESCAPE OR InputManager.keyCode = KEY_UPPER_N OR InputManager.keyCode = KEY_LOWER_N THEN
            EXIT DO

        ELSEIF _TOTALDROPPEDFILES > 0 THEN
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
            IF _MESSAGEBOX(APP_NAME, "Are you sure you want to delete " + fileName + " permanently?", "yesno", "question", 0) = 1 THEN
                KILL fileName
                EXIT DO
            END IF

        END IF

        _LIMIT FRAME_RATE_MAX
    LOOP UNTIL NOT MIDI_IsPlaying

    MIDI_Stop

    ' Clear these so that we do not keep showing dead info
    TuneTitle = STRING_EMPTY
    ElapsedTicks = NULL

    _TITLE APP_NAME ' set app title to the way it was
END FUNCTION


' Welcome screen loop
FUNCTION OnWelcomeScreen%%
    SHARED InputManager AS InputManagerType

    DIM e AS _BYTE: e = EVENT_NONE

    DO
        DrawScreen

        IF InputManager.keyCode = KEY_ESCAPE THEN
            e = EVENT_QUIT

        ELSEIF _TOTALDROPPEDFILES > 0 THEN
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

        _LIMIT FRAME_RATE_MAX
    LOOP WHILE e = EVENT_NONE

    OnWelcomeScreen = e
END FUNCTION


' Processes the command line one file at a time
FUNCTION OnCommandLine%%
    DIM e AS _BYTE: e = EVENT_NONE

    IF GetProgramArgumentIndex(KEY_QUESTION_MARK) > 0 THEN
        ShowAboutDialog
        e = EVENT_QUIT
    ELSE
        DIM i AS LONG: FOR i = 1 TO _COMMANDCOUNT
            e = OnPlayMIDITune(COMMAND$(i))
            IF e <> EVENT_PLAY THEN EXIT FOR
        NEXT
    END IF

    OnCommandLine = e
END FUNCTION


' Processes dropped files one file at a time
FUNCTION ProcessDroppedFiles%%
    ' Make a copy of the dropped file and clear the list
    REDIM fileNames(1 TO _TOTALDROPPEDFILES) AS STRING

    DIM e AS _BYTE: e = EVENT_NONE

    DIM i AS LONG: FOR i = 1 TO _TOTALDROPPEDFILES
        fileNames(i) = _DROPPEDFILE(i)
    NEXT
    _FINISHDROP ' This is critical

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
    DIM e AS _BYTE: e = EVENT_NONE

    ofdList = _OPENFILEDIALOG$(APP_NAME, , "*.mid|*.MID|*.Mid|*.midi|*.MIDI|*.Midi", "Standard MIDI Files", TRUE)

    IF LEN(ofdList) = NULL THEN EXIT FUNCTION

    REDIM fileNames(0 TO 0) AS STRING

    DIM j AS LONG: j = String_Tokenize(ofdList, "|", STRING_EMPTY, FALSE, fileNames())

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
'$INCLUDE:'include/GraphicOps.bas'
'$INCLUDE:'include/Pathname.bas'
'$INCLUDE:'include/StringOps.bas'
'$INCLUDE:'include/Base64.bas'
'$INCLUDE:'include/ImGUI.bas'
'$INCLUDE:'include/WinMIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------
