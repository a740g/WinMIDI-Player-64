'-----------------------------------------------------------------------------------------------------------------------
' QB64-PE MIDI Player
' Copyright (c) 2024 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'include/GraphicOps.bi'
'$INCLUDE:'include/Pathname.bi'
'$INCLUDE:'include/StringOps.bi'
'$INCLUDE:'include/ImGUI.bi'
'$INCLUDE:'include/MIDIPlayer.bi'
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
$VERSIONINFO:FILEVERSION#=3,0,0,0
$VERSIONINFO:PRODUCTVERSION#=3,0,0,0
$EXEICON:'./WinMIDIPlayer64.ico'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
CONST APP_NAME = "WinMIDI Player 64"

CONST SCREEN_WIDTH& = 640&
CONST SCREEN_HEIGHT& = 400&

CONST FRAME_COLOR~& = _RGBA32(0, 0, 0, 128)
CONST FRAME_BORDER_WIDTH_X& = 48&
CONST FRAME_BORDER_WIDTH_Y& = 64&

CONST BUTTON_FONT& = 14&
CONST BUTTON_WIDTH& = 96&
CONST BUTTON_HEIGHT& = 32&
CONST BUTTON_GAP& = 8&
CONST BUTTON_COUNT& = 5&
CONST BUTTON_X& = SCREEN_WIDTH \ 2& - (BUTTON_WIDTH * BUTTON_COUNT + BUTTON_GAP * (BUTTON_COUNT - 1)) \ 2&
CONST BUTTON_Y& = SCREEN_HEIGHT - (FRAME_BORDER_WIDTH_X + BUTTON_HEIGHT) \ 2&

CONST VOLUME_TEXT_X& = (SCREEN_WIDTH - 4& * 8&) \ 2&
CONST VOLUME_TEXT_Y& = (SCREEN_HEIGHT \ 2&) + (BUTTON_FONT * 4&)

CONST BUTTON_VOLUME_M_X& = VOLUME_TEXT_X - BUTTON_GAP * 2& - BUTTON_HEIGHT
CONST BUTTON_VOLUME_P_X& = VOLUME_TEXT_X + 4& * 8& + BUTTON_GAP * 2&
CONST BUTTON_VOLUME_Y& = VOLUME_TEXT_Y - (BUTTON_HEIGHT - BUTTON_FONT) \ 2&

CONST REEL_COLOR~& = BGRA_WHITE
CONST REEL_RADIUS& = 37&
CONST REEL_LEFT_X& = 190&
CONST REEL_RIGHT_X& = 446&
CONST REEL_Y& = 184&

CONST WP_DIV& = 8&
CONST WP_WIDTH& = SCREEN_WIDTH \ WP_DIV
CONST WP_HEIGHT& = SCREEN_HEIGHT \ WP_DIV

CONST TITLE_WIDTH& = SCREEN_WIDTH - FRAME_BORDER_WIDTH_Y * 3&
CONST TITLE_CHARS& = TITLE_WIDTH \ 8&
CONST TITLE_X& = (FRAME_BORDER_WIDTH_Y * 3&) \ 2&
CONST TITLE_Y& = BUTTON_FONT * 2& + FRAME_BORDER_WIDTH_X

CONST TIME_X& = (SCREEN_WIDTH - 13& * 8&) \ 2&
CONST TIME_Y& = (SCREEN_HEIGHT \ 2&) - (BUTTON_FONT * 2&)

CONST PLAY_ICON_X& = (SCREEN_WIDTH - 1& * 8&) \ 2&
CONST PLAY_ICON_Y& = (SCREEN_HEIGHT \ 2&)

CONST FRAME_RATE_MAX& = 60&

' Program events
CONST EVENT_NONE%% = 0%% ' idle
CONST EVENT_QUIT%% = 1%% ' user wants to quit
CONST EVENT_CMDS%% = 2%% ' process command line
CONST EVENT_LOAD%% = 3%% ' user want to load files
CONST EVENT_DROP%% = 4%% ' user dropped files
CONST EVENT_PLAY%% = 5%% ' play next song
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
    $RESIZE:SMOOTH
    SCREEN _NEWIMAGE(SCREEN_WIDTH, SCREEN_HEIGHT, 32)
    _TITLE APP_NAME ' set default app title
    CHDIR _STARTDIR$ ' change to the directory specifed by the environment
    _ACCEPTFILEDROP ' enable drag and drop of files
    _ALLOWFULLSCREEN _SQUAREPIXELS , _SMOOTH ' allow the user to press Alt+Enter to go fullscreen
    _DISPLAYORDER _HARDWARE , _HARDWARE1 , _GLRENDER , _SOFTWARE ' draw the software stuff + text at the end
    _PRINTMODE _KEEPBACKGROUND ' set text rendering to preserve backgroud
    _FONT BUTTON_FONT

    ' Decode, decompress, and load the background from memory to an image
    BackgroundImage = _LOADIMAGE(Base64_LoadResourceString(DATA_COMPACTCASSETTE_PNG_BI_42837, SIZE_COMPACTCASSETTE_PNG_BI_42837, COMP_COMPACTCASSETTE_PNG_BI_42837), 33, "memory, hq2xb")

    DIM buttonX AS LONG: buttonX = BUTTON_X ' this is where we will start
    UI.cmdOpen = PushButtonNew("Open", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _FALSE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdPlayPause = PushButtonNew("Play", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _TRUE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdNext = PushButtonNew("Next", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _FALSE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdRepeat = PushButtonNew("Loop", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _TRUE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdAbout = PushButtonNew("About", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _FALSE)
    UI.cmdDecVolume = PushButtonNew("-V", BUTTON_VOLUME_M_X, BUTTON_VOLUME_Y, BUTTON_HEIGHT, BUTTON_HEIGHT, _FALSE)
    UI.cmdIncVolume = PushButtonNew("+V", BUTTON_VOLUME_P_X, BUTTON_VOLUME_Y, BUTTON_HEIGHT, BUTTON_HEIGHT, _FALSE)

    _DISPLAY ' only swap display buffer when we want
END SUB


' Weird plasma effect
SUB DrawWeirdPlasma
    $CHECKING:OFF

    STATIC AS LONG w, h, t, imgHandle
    STATIC imgMem AS _MEM

    DIM rW AS LONG: rW = WP_WIDTH
    DIM rH AS LONG: rH = WP_HEIGHT

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
        x = 0&
        g1 = 128! * SIN(y / 16! - t / 22!)
        r2 = 128! * SIN(y / 32! + t / 26!)

        WHILE x < w
            r1 = 128! * SIN(x / 16! - t / 20!)
            b1 = 128! * SIN((x + y) / 32! - t / 24!)
            g2 = 128! * SIN(x / 32! + t / 28!)
            b2 = 128! * SIN((x - y) / 32! + t / 30!)

            _MEMPUT imgMem, imgMem.OFFSET + (4& * w * y) + x * 4&, _RGB32((r1 + r2) / 2!, (g1 + g2) / 2!, (b1 + b2) / 2!) AS _UNSIGNED LONG

            x = x + 1&
        WEND

        y = y + 1&
    WEND

    DIM imgGPUHandle AS LONG: imgGPUHandle = _COPYIMAGE(imgHandle, 33)
    _PUTIMAGE , imgGPUHandle
    _FREEIMAGE imgGPUHandle

    t = t + 1&

    $CHECKING:ON
END SUB


' Draws one cassette reel
SUB DrawReel (x AS LONG, y AS LONG, a AS SINGLE)
    STATIC drawCmds AS STRING, clr AS _UNSIGNED LONG
    STATIC AS LONG angle, xp, yp

    ' These must be copied to static variables for VARPTR$ to work correctly
    angle = a
    xp = x
    yp = y
    clr = REEL_COLOR

    ' We'll setup the DRAW commands just once to a STATIC string
    IF LEN(drawCmds) = 0 THEN drawCmds = "C=" + VARPTR$(clr) + "BM=" + VARPTR$(xp) + ",=" + VARPTR$(yp) + "TA=" + VARPTR$(angle) + "BU35BR1D10L1U10L1D10"

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
    Graphics_DrawCircle xp, yp, REEL_RADIUS, clr
    Graphics_DrawCircle xp, yp, REEL_RADIUS - 1, clr
END SUB


' Draws both reels at correct locations and manages rotation
SUB DrawReels
    STATIC angle AS _UNSIGNED LONG

    DrawReel REEL_LEFT_X, REEL_Y, angle
    DrawReel REEL_RIGHT_X, REEL_Y, angle

    IF NOT MIDI_IsPaused THEN angle = angle + 1
END SUB


' Draws a frame around the screen
SUB DrawFrame
    Graphics_DrawFilledRectangle 0, 0, SCREEN_WIDTH - 1, FRAME_BORDER_WIDTH_X - 1, FRAME_COLOR
    Graphics_DrawFilledRectangle 0, SCREEN_HEIGHT - FRAME_BORDER_WIDTH_X, SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1, FRAME_COLOR
    Graphics_DrawFilledRectangle 0, FRAME_BORDER_WIDTH_X, FRAME_BORDER_WIDTH_Y - 1, SCREEN_HEIGHT - FRAME_BORDER_WIDTH_X - 1, FRAME_COLOR
    Graphics_DrawFilledRectangle SCREEN_WIDTH - FRAME_BORDER_WIDTH_Y, FRAME_BORDER_WIDTH_X, SCREEN_WIDTH - 1, SCREEN_HEIGHT - FRAME_BORDER_WIDTH_X - 1, FRAME_COLOR
END SUB


' This draws everything to the screen
SUB DrawScreen
    CLS , 0 ' clear screen with black with no alpha
    DrawWeirdPlasma
    _PUTIMAGE , BackgroundImage
    DrawReels
    DrawFrame

    DIM text AS STRING: text = LEFT$(TuneTitle, TITLE_CHARS)

    COLOR BGRA_BLACK
    _PRINTSTRING (TITLE_X + (TITLE_WIDTH - _PRINTWIDTH(text)) \ 2, TITLE_Y), text

    DIM ctm AS _UNSIGNED LONG: ctm = _CAST(_UNSIGNED LONG, MIDI_GetCurrentTime / 60)
    DIM cts AS _UNSIGNED LONG: cts = _CAST(_UNSIGNED LONG, MIDI_GetCurrentTime MOD 60)
    DIM ttm AS _UNSIGNED LONG: ttm = _CAST(_UNSIGNED LONG, MIDI_GetTotalTime / 60)
    DIM tts AS _UNSIGNED LONG: tts = _CAST(_UNSIGNED LONG, MIDI_GetTotalTime MOD 60)

    COLOR BGRA_WHITE
    _PRINTSTRING (TIME_X, TIME_Y), String_FormatLong(ctm, "%02u:") + String_FormatLong(cts, "%02u / ") + String_FormatLong(ttm, "%02u:") + String_FormatLong(tts, "%02u")

    COLOR BGRA_BLACK
    _PRINTSTRING (VOLUME_TEXT_X, VOLUME_TEXT_Y), String_FormatLong(_CAST(_UNSIGNED LONG, MIDI_GetVolume * 100#), "%3u%%")

    IF MIDI_IsPaused THEN
        COLOR BGRA_ORANGERED
        _PRINTSTRING (PLAY_ICON_X - 4, PLAY_ICON_Y), STRING$(2, 179)
    ELSE
        COLOR BGRA_YELLOW
        _PRINTSTRING (PLAY_ICON_X, PLAY_ICON_Y), CHR$(16)
    END IF

    WidgetDisabled UI.cmdPlayPause, LEN(TuneTitle) = 0
    WidgetDisabled UI.cmdNext, LEN(TuneTitle) = 0
    WidgetDisabled UI.cmdRepeat, LEN(TuneTitle) = 0
    PushButtonDepressed UI.cmdPlayPause, NOT MIDI_IsPaused _ANDALSO LEN(TuneTitle) <> 0
    PushButtonDepressed UI.cmdRepeat, MIDI_IsLooping

    WidgetUpdate ' draw widgets above everything else. This also fetches input

    _DISPLAY ' flip the framebuffer
END SUB


' Shows the About dialog box
SUB ShowAboutDialog
    DIM tunePaused AS _BYTE

    IF MIDI_IsPlaying _ANDALSO NOT MIDI_IsPaused THEN
        MIDI_Pause _TRUE
        tunePaused = _TRUE
    END IF

    RESTORE data_raindrop_wav_bi_482216
    DIM hSnd AS LONG: hSnd = _SNDOPEN(Base64_LoadResourceData, "memory")

    IF hSnd THEN
        _SNDVOL hSnd, 0.25!
        _SNDLOOP hSnd
    END IF

    _MESSAGEBOX APP_NAME, APP_NAME + STRING$(2, _CHR_LF) + _
        "Syntax: WinMIDIPlayer64 [-?] [midifile1.mid] [midifile2.mid] ..." + _CHR_LF + _
        "    -?: Shows this message" + STRING$(2, _CHR_LF) + _
        "Copyright (c) 2024, Samuel Gomes" + STRING$(2, _CHR_LF) + _
        "https://github.com/a740g/", "info"

    IF hSnd THEN
        _SNDSTOP hSnd
        _SNDCLOSE hSnd
    END IF

    IF tunePaused THEN MIDI_Pause _FALSE
END SUB


' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
FUNCTION OnPlayMIDITune%% (fileName AS STRING)
    SHARED InputManager AS InputManagerType

    OnPlayMIDITune = EVENT_PLAY ' default event is to play next song

    IF NOT MIDI_PlayFromFile(fileName) THEN ' We want the MIDI file to loop just once
        _MESSAGEBOX APP_NAME, "Failed to load: " + fileName + STRING$(2, _CHR_LF) + "Reason: " + MIDI_GetErrorMessage, "error"
        EXIT FUNCTION
    END IF

    ' Set the app title to display the file name
    TuneTitle = Pathname_GetFileName(fileName)
    _TITLE TuneTitle + " - " + APP_NAME ' show complete filename in the title
    TuneTitle = LEFT$(TuneTitle, LEN(TuneTitle) - LEN(Pathname_GetFileExtension(TuneTitle))) ' get the file name without the extension

    DO
        DrawScreen

        IF WidgetClicked(UI.cmdNext) _ORELSE InputManager.keyCode = _KEY_ESC _ORELSE InputManager.keyCode = KEY_UPPER_N _ORELSE InputManager.keyCode = KEY_LOWER_N THEN
            EXIT DO

        ELSEIF _TOTALDROPPEDFILES > 0 THEN
            OnPlayMIDITune = EVENT_DROP
            EXIT DO

        ELSEIF WidgetClicked(UI.cmdOpen) _ORELSE InputManager.keyCode = KEY_UPPER_O _ORELSE InputManager.keyCode = KEY_LOWER_O THEN
            OnPlayMIDITune = EVENT_LOAD
            EXIT DO

        ELSEIF WidgetClicked(UI.cmdPlayPause) _ORELSE InputManager.keyCode = KEY_UPPER_P _ORELSE InputManager.keyCode = KEY_LOWER_P THEN
            MIDI_Pause NOT MIDI_IsPaused

        ELSEIF WidgetClicked(UI.cmdRepeat) _ORELSE InputManager.keyCode = KEY_UPPER_L _ORELSE InputManager.keyCode = KEY_LOWER_L THEN
            MIDI_Loop NOT MIDI_IsLooping

        ELSEIF WidgetClicked(UI.cmdIncVolume) _ORELSE InputManager.keyCode = KEY_PLUS _ORELSE InputManager.keyCode = KEY_EQUALS THEN
            MIDI_SetVolume MIDI_GetVolume + 0.01!

        ELSEIF WidgetClicked(UI.cmdDecVolume) _ORELSE InputManager.keyCode = KEY_MINUS _ORELSE InputManager.keyCode = KEY_UNDERSCORE THEN
            MIDI_SetVolume MIDI_GetVolume - 0.01!

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
    TuneTitle = _STR_EMPTY

    _TITLE APP_NAME ' set app title to the way it was
END FUNCTION


' Welcome screen loop
FUNCTION OnWelcomeScreen%%
    SHARED InputManager AS InputManagerType

    DIM e AS _BYTE: e = EVENT_NONE

    DO
        DrawScreen

        IF InputManager.keyCode = _KEY_ESC THEN
            e = EVENT_QUIT

        ELSEIF _TOTALDROPPEDFILES > 0 THEN
            e = EVENT_DROP

        ELSEIF WidgetClicked(UI.cmdOpen) _ORELSE InputManager.keyCode = KEY_UPPER_O _ORELSE InputManager.keyCode = KEY_LOWER_O THEN
            e = EVENT_LOAD

        ELSEIF WidgetClicked(UI.cmdIncVolume) _ORELSE InputManager.keyCode = KEY_PLUS _ORELSE InputManager.keyCode = KEY_EQUALS THEN
            MIDI_SetVolume MIDI_GetVolume + 0.01!

        ELSEIF WidgetClicked(UI.cmdDecVolume) _ORELSE InputManager.keyCode = KEY_MINUS _ORELSE InputManager.keyCode = KEY_UNDERSCORE THEN
            MIDI_SetVolume MIDI_GetVolume - 0.01!

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

    ofdList = _OPENFILEDIALOG$(APP_NAME, , "*.mid|*.MID|*.Mid|*.midi|*.MIDI|*.Midi", "Standard MIDI Files", _TRUE)

    IF LEN(ofdList) = NULL THEN EXIT FUNCTION

    REDIM fileNames(0 TO 0) AS STRING

    DIM j AS LONG: j = String_Tokenize(ofdList, "|", _STR_EMPTY, _FALSE, fileNames())

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
'$INCLUDE:'include/MIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------
