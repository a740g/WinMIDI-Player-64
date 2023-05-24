'-----------------------------------------------------------------------------------------------------------------------
' QB64-PE Windows MIDI Player
' Copyright (c) 2023 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$Include:'include/FileOps.bi'
'$Include:'include/Base64.bi'
'$Include:'include/ImGUI.bi'
'$Include:'include/WinMIDIPlayer.bi'
'$Include:'compactcassette.png.bi'
'$Include:'raindrop.wav.bi'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
$ExeIcon:'./WinMIDIPlayer64.ico'
$VersionInfo:CompanyName=Samuel Gomes
$VersionInfo:FileDescription=WinMIDI Player 64 executable
$VersionInfo:InternalName=WinMIDIPlayer64
$VersionInfo:LegalCopyright=Copyright (c) 2023, Samuel Gomes
$VersionInfo:LegalTrademarks=All trademarks are property of their respective owners
$VersionInfo:OriginalFilename=WinMIDIPlayer64.exe
$VersionInfo:ProductName=WinMIDI Player 64
$VersionInfo:Web=https://github.com/a740g
$VersionInfo:Comments=https://github.com/a740g
$VersionInfo:FILEVERSION#=2,0,0,0
$VersionInfo:PRODUCTVERSION#=2,0,0,0
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
Const APP_NAME = "WinMIDI Player 64"
Const FRAME_RATE_MAX = 120
' Program events
Const EVENT_NONE = 0 ' idle
Const EVENT_QUIT = 1 ' user wants to quit
Const EVENT_CMDS = 2 ' process command line
Const EVENT_LOAD = 3 ' user want to load files
Const EVENT_DROP = 4 ' user dropped files
Const EVENT_PLAY = 5 ' play next song
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' USER DEFINED TYPES
'-----------------------------------------------------------------------------------------------------------------------
Type UIType ' bunch of UI widgets to change stuff
    cmdOpen As Long ' open dialog box button
    cmdPlayPause As Long ' play / pause button
    cmdNext As Long ' next tune button
    cmdIncVolume As Long ' increase volume button
    cmdDecVolume As Long ' decrease volume button
    cmdRepeat As Long ' repeat enable / disable button
    cmdAbout As Long ' shows an about dialog
End Type
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------------------------
Dim Shared MIDIVolume As Single ' global MIDI volume
Dim Shared ElapsedTicks As Unsigned Integer64 ' amount of time spent in playing the current tune
Dim Shared TuneTitle As String '  tune title
Dim Shared BackgroundImage As Long ' the CC image that we will use for the background
Dim Shared UI As UIType ' user interface controls
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
InitProgram

Dim event As Unsigned Byte: event = EVENT_CMDS ' default to command line event first

' Main loop
Do
    Select Case event
        Case EVENT_QUIT
            Exit Do

        Case EVENT_DROP
            event = ProcessDroppedFiles

        Case EVENT_LOAD
            event = ProcessSelectedFiles

        Case EVENT_CMDS
            event = ProcessCommandLine

        Case Else
            event = DoWelcomeScreen
    End Select
Loop Until event = EVENT_QUIT

AutoDisplay
WidgetFreeAll
FreeImage BackgroundImage
System
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------------------------
' Initializes everything we need
Sub InitProgram
    Const BUTTON_WIDTH = 48 ' default button width
    Const BUTTON_HEIGHT = 24 ' default button height
    Const BUTTON_GAP = 4 ' default gap between buttons
    Const BUTTON_Y = 172 ' default button top

    Screen NewImage(320, 200, 32) ' like SCREEN 13 but in 32bpp
    Title APP_NAME ' set default app title
    ChDir StartDir$ ' change to the directory specifed by the environment
    AcceptFileDrop ' enable drag and drop of files
    AllowFullScreen SquarePixels , Smooth ' allow the user to press Alt+Enter to go fullscreen
    Font 8 ' use 8x8 font by default
    PrintMode KeepBackground ' set text rendering to preserve backgroud
    ' Next 2 lines load the background, decodes, decompresses and loads it from memory to an image
    Restore Data_compactcassette_png_46482
    BackgroundImage = LoadImage(LoadResource, , "memory")
    MIDIVolume = 1 ' set initial volume at 100%

    Dim buttonX As Long: buttonX = 32 ' this is where we will start
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

    Display ' only swap display buffer when we want
End Sub

' Weird plasma effect
' This is slow AF. We should probably use a Sine LUT
' But it is kinda ok for a 320x200 pix screen
Sub DrawWeirdPlasma
    Dim As Long x, y, r, g, b, r2, g2, b2, right, bottom, xs, ys
    Static t As Long

    right = Width - 1
    bottom = Height - 1

    For y = 0 To bottom Step 2
        For x = xs To right Step 2
            r = 96 + 128 * Sin(x / 16 - t / 20)
            g = 96 + 128 * Sin(y / 16 - t / 22)
            b = 96 + 128 * Sin((x + y) / 32 - t / 24)
            r2 = 96 + 128 * Sin(y / 32 + t / 26)
            g2 = 96 + 128 * Sin(x / 32 + t / 28)
            b2 = 96 + 128 * Sin((x - y) / 32 + t / 30)
            PSet (x, ys + y), RGB32((r + r2) \ 2, (g + g2) \ 2, (b + b2) \ 2)
            ys = 1 - ys
        Next
        xs = 1 - xs
    Next

    t = t + 1
End Sub

' Draws one cassette reel
Sub DrawReel (x As Long, y As Long, c As Unsigned Long, a As Single)
    Static drawCmds As String, angle As Unsigned Long

    drawCmds = "C" + Str$(c) + "BM" + Str$(x) + "," + Str$(y) + "TA=" + VarPtr$(angle) + "BU17L1D5R1U5"

    ' Faster without loop
    angle = a
    Draw drawCmds
    angle = angle + 45
    Draw drawCmds
    angle = angle + 45
    Draw drawCmds
    angle = angle + 45
    Draw drawCmds
    angle = angle + 45
    Draw drawCmds
    angle = angle + 45
    Draw drawCmds
    angle = angle + 45
    Draw drawCmds
    angle = angle + 45
    Draw drawCmds
    Circle (x, y), 18, c
End Sub


' Draws both reels at correct locations and manages rotation
Sub DrawReels
    Static angle As Unsigned Long

    DrawReel 95, 92, White, angle
    DrawReel 223, 92, White, angle

    If Not MIDI_IsPaused Then angle = angle + 1
End Sub

' Draws a frame around the CC
Sub DrawFrame
    Const FRAME_COLOR = RGBA32(0, 0, 0, 128)

    Line (0, 0)-(319, 23), FRAME_COLOR, BF
    Line (0, 167)-(319, 199), FRAME_COLOR, BF
    Line (0, 24)-(31, 166), FRAME_COLOR, BF
    Line (287, 24)-(319, 166), FRAME_COLOR, BF
End Sub

' This draws everything to the screen
Sub DrawScreen
    Cls , Black
    DrawWeirdPlasma
    PutImage , BackgroundImage
    DrawReels
    DrawFrame

    Dim text As String: text = Left$(TuneTitle, 28)
    Font 14
    Color Black
    Locate 4, 7 + (14 - Len(text) \ 2)
    Print text;

    Dim minute As Unsigned Long: minute = ElapsedTicks \ 60000
    Dim second As Unsigned Long: second = (ElapsedTicks Mod 60000) \ 1000
    Color White
    Locate 7, 18
    Print Right$("00" + LTrim$(Str$(minute)), 3); ":"; Right$("00" + LTrim$(Str$(second)), 2);

    Font 16
    Color Black
    Locate 9, 19
    Print Right$("  " + LTrim$(Str$(Round(MIDIVolume * 100))), 3); "%";

    Font 8
    Locate 14, 20
    If MIDI_IsPaused Then
        Color OrangeRed
        Print String$(2, 179);
    Else
        Color Yellow
        Print String$(2, 16);
    End If

    WidgetDisabled UI.cmdPlayPause, Len(TuneTitle) = 0
    WidgetDisabled UI.cmdNext, Len(TuneTitle) = 0
    WidgetDisabled UI.cmdRepeat, Len(TuneTitle) = 0
    PushButtonDepressed UI.cmdPlayPause, Not MIDI_IsPaused And Len(TuneTitle) <> 0
    PushButtonDepressed UI.cmdRepeat, MIDI_IsLooping

    WidgetUpdate ' draw widgets above everything else. This also fetches input

    Display ' flip the framebuffer
End Sub

' Shows the About dialog box
Sub ShowAboutDialog
    Dim tunePaused As Byte

    If MIDI_IsPlaying And Not MIDI_IsPaused Then
        MIDI_Pause TRUE
        tunePaused = TRUE
    End If

    Restore Data_raindrop_wav_482216
    Sound_PlayFromMemory LoadResource, TRUE

    MessageBox APP_NAME, APP_NAME + String$(2, KEY_ENTER) + _
        "Syntax: WinMIDIPlayer64 [-?] [midifile1.mid] [midifile2.mid] ..." + Chr$(KEY_ENTER) + _
        "    -?: Shows this message" + String$(2, KEY_ENTER) + _
        "Copyright (c) 2023, Samuel Gomes" + String$(2, KEY_ENTER) + _
        "https://github.com/a740g/", "info"

    Sound_Stop

    If tunePaused Then MIDI_Pause FALSE
End Sub

' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
Function PlayMIDITune~%% (fileName As String)
    Shared InputManager As InputManagerType

    PlayMIDITune = EVENT_PLAY ' default event is to play next song
    Dim As Unsigned Integer64 currentTick, lastTick

    lastTick = GetTicks

    If Not MIDI_PlayFromFile(fileName) Then ' We want the MIDI file to loop just once
        MessageBox APP_NAME, "Failed to load: " + fileName, "error"
        Exit Function
    End If

    ' Set the app title to display the file name
    TuneTitle = GetFileNameFromPathOrURL(fileName)
    Title TuneTitle + " - " + APP_NAME ' show complete filename in the title
    TuneTitle = Left$(TuneTitle, Len(TuneTitle) - Len(GetFileExtensionFromPathOrURL(TuneTitle))) ' get the file name without the extension

    MIDI_SetVolume MIDIVolume ' set the volume as Windows will reset the volume for new MIDI streams

    Do
        currentTick = GetTicks
        If currentTick > lastTick And Not MIDI_IsPaused Then ElapsedTicks = ElapsedTicks + (currentTick - lastTick)
        lastTick = currentTick

        DrawScreen

        If WidgetClicked(UI.cmdNext) Or InputManager.keyCode = KEY_ESCAPE Or InputManager.keyCode = KEY_UPPER_N Or InputManager.keyCode = KEY_LOWER_N Then
            Exit Do

        ElseIf TotalDroppedFiles > 0 Then
            PlayMIDITune = EVENT_DROP
            Exit Do

        ElseIf WidgetClicked(UI.cmdOpen) Or InputManager.keyCode = KEY_UPPER_O Or InputManager.keyCode = KEY_LOWER_O Then
            PlayMIDITune = EVENT_LOAD
            Exit Do

        ElseIf WidgetClicked(UI.cmdPlayPause) Or InputManager.keyCode = KEY_UPPER_P Or InputManager.keyCode = KEY_LOWER_P Then
            MIDI_Pause Not MIDI_IsPaused

        ElseIf WidgetClicked(UI.cmdRepeat) Or InputManager.keyCode = KEY_UPPER_L Or InputManager.keyCode = KEY_LOWER_L Then
            MIDI_Loop Not MIDI_IsLooping

        ElseIf WidgetClicked(UI.cmdIncVolume) Or InputManager.keyCode = KEY_PLUS Or InputManager.keyCode = KEY_EQUALS Then
            MIDIVolume = MIDIVolume + 0.01
            MIDI_SetVolume MIDIVolume
            MIDIVolume = MIDI_GetVolume

        ElseIf WidgetClicked(UI.cmdDecVolume) Or InputManager.keyCode = KEY_MINUS Or InputManager.keyCode = KEY_UNDERSCORE Then
            MIDIVolume = MIDIVolume - 0.01
            MIDI_SetVolume MIDIVolume
            MIDIVolume = MIDI_GetVolume

        ElseIf WidgetClicked(UI.cmdAbout) Then
            ShowAboutDialog

        ElseIf InputManager.keyCode = 21248 Then ' shift + delete - you know what this does :)
            If MessageBox(APP_NAME, "Are you sure you want to delete " + fileName + " permanently?", "yesno", "question", 0) = 1 Then
                Kill fileName
                Exit Do
            End If

        End If

        Limit FRAME_RATE_MAX
    Loop Until Not MIDI_IsPlaying

    MIDI_Stop

    ' Clear these so that we do not keep showing dead info
    TuneTitle = NULLSTRING
    ElapsedTicks = NULL

    Title APP_NAME ' set app title to the way it was
End Function


' Welcome screen loop
Function DoWelcomeScreen~%%
    Shared InputManager As InputManagerType

    Dim e As Unsigned Byte: e = EVENT_NONE

    Do
        DrawScreen

        If InputManager.keyCode = KEY_ESCAPE Then
            e = EVENT_QUIT

        ElseIf TotalDroppedFiles > 0 Then
            e = EVENT_DROP

        ElseIf WidgetClicked(UI.cmdOpen) Or InputManager.keyCode = KEY_UPPER_O Or InputManager.keyCode = KEY_LOWER_O Then
            e = EVENT_LOAD

        ElseIf WidgetClicked(UI.cmdIncVolume) Or InputManager.keyCode = KEY_PLUS Or InputManager.keyCode = KEY_EQUALS Then
            MIDIVolume = MIDIVolume + 0.01
            If MIDIVolume > 1 Then MIDIVolume = 1

        ElseIf WidgetClicked(UI.cmdDecVolume) Or InputManager.keyCode = KEY_MINUS Or InputManager.keyCode = KEY_UNDERSCORE Then
            MIDIVolume = MIDIVolume - 0.01
            If MIDIVolume < 0 Then MIDIVolume = 0

        ElseIf WidgetClicked(UI.cmdAbout) Then
            ShowAboutDialog

        End If

        Limit FRAME_RATE_MAX
    Loop While e = EVENT_NONE

    DoWelcomeScreen = e
End Function


' Processes the command line one file at a time
Function ProcessCommandLine~%%
    Dim i As Unsigned Long
    Dim e As Unsigned Byte: e = EVENT_NONE

    If GetProgramArgumentIndex(KEY_QUESTION_MARK) > 0 Then
        ShowAboutDialog
        e = EVENT_QUIT
    Else
        For i = 1 To CommandCount
            e = PlayMIDITune(Command$(i))
            If e <> EVENT_PLAY Then Exit For
        Next
    End If

    ProcessCommandLine = e
End Function


' Processes dropped files one file at a time
Function ProcessDroppedFiles~%%
    ' Make a copy of the dropped file and clear the list
    ReDim fileNames(1 To TotalDroppedFiles) As String
    Dim i As Unsigned Long
    Dim e As Unsigned Byte: e = EVENT_NONE

    For i = 1 To TotalDroppedFiles
        fileNames(i) = DroppedFile(i)
    Next
    FinishDrop ' This is critical

    ' Now play the dropped file one at a time
    For i = LBound(fileNames) To UBound(fileNames)
        e = PlayMIDITune(fileNames(i))
        If e <> EVENT_PLAY Then Exit For
    Next

    ProcessDroppedFiles = e
End Function


' Processes a list of files selected by the user
Function ProcessSelectedFiles~%%
    Dim ofdList As String
    Dim e As Unsigned Byte: e = EVENT_NONE

    ofdList = OpenFileDialog$(APP_NAME, , "*.mid|*.MID|*.Mid|*.midi|*.MIDI|*.Midi", "Standard MIDI Files", TRUE)

    If ofdList = NULLSTRING Then Exit Function

    ReDim fileNames(0 To 0) As String
    Dim As Long i, j

    j = ParseOpenFileDialogList(ofdList, fileNames())

    For i = 0 To j - 1
        e = PlayMIDITune(fileNames(i))
        If e <> EVENT_PLAY Then Exit For
    Next

    ProcessSelectedFiles = e
End Function
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------------------------
'$Include:'include/ProgramArgs.bas'
'$Include:'include/FileOps.bas'
'$Include:'include/Base64.bas'
'$Include:'include/ImGUI.bas'
'$Include:'include/WinMIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------

