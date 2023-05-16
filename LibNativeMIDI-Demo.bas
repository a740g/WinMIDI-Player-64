'-----------------------------------------------------------------------------------------------------
' LibNativeMIDI Demo
' Copyright (c) 2023 Samuel Gomes
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------
'$Include:'include/CRTLib.bi'
'$Include:'include/FileOps.bi'
'$Include:'include/WinMIDIPlayer.bi'
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------
Const APP_NAME = "LibNativeMIDI Player Demo"
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------
Dim Shared Volume As Single
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------
Title APP_NAME + " " + OS$ ' Set app title to the way it was
ChDir StartDir$ ' Change to the directory specifed by the environment
AcceptFileDrop ' Enable drag and drop of files
AllowFullScreen SquarePixels , Smooth ' All the user to press Alt+Enter to go fullscreen
Volume = 1 ' Set initial volume as 100%

ProcessCommandLine ' Check if any files were specified in the command line

Dim k As Long

' Main loop
Do
    Cls
    Print APP_NAME
    Print "-------------------------"
    Print
    Print "DRAG AND DROP MULTIPLE MIDI FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY."
    Print "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE."
    Print "THIS WAS WRITTEN IN QB64 AND THE SOURCE CODE IS AVAILABLE ON GITHUB."
    Print "https://github.com/a740g/QB64-LibNativeMIDI"

    PlayWAV

    Do
        k = KeyHit
        Limit 60
    Loop Until k <> 0 Or TotalDroppedFiles > 0

    PlayWAV
    ProcessDroppedFiles
Loop Until k = KEY_ESCAPE

If MIDI_Play(Chr$(NULL), 0) Then
    Print: Print "LibNativeMIDI shutdown successfully."
End If

End
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------
' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
Sub PlaySong (fileName As String)
    Dim As Unsigned Integer64 currentTick, lastTick, elapsedTicks

    lastTick = GetTicks

    If Not MIDI_Play(fileName, 1) Then ' We want the MIDI file to loop just once
        Print: Print "Failed to load "; fileName; "!"
        Exit Sub
    End If

    ' Set the app title to display the file name
    Title APP_NAME + " - " + GetFileNameFromPathOrURL(fileName)

    Print: Print "Playing "; GetFileNameFromPathOrURL(fileName); " (press ESC to stop, SPC to pause, +/- for volume)..."

    Dim As String minute, second, sPaused
    Dim k As Long, paused As Byte

    MIDI_SetVolume Volume

    Do
        currentTick = GetTicks
        If currentTick > lastTick And Not paused Then elapsedTicks = elapsedTicks + (currentTick - lastTick)
        lastTick = currentTick

        Locate , 1
        minute = Right$("00" + LTrim$(Str$(elapsedTicks \ 60000)), 2)
        second = Right$("00" + LTrim$(Str$((elapsedTicks Mod 60000) \ 1000)), 2)
        If paused Then sPaused = "Paused " Else sPaused = "Playing"
        Print Using "Elapsed time: &:& (mm:ss) | Volume = ###.##% | &"; minute; second; Volume * 100; sPaused;
        'Print elapsedTicks; currentTick; lastTick;

        k = KeyHit

        Select Case k
            Case KEY_SPACE_BAR
                paused = Not paused
                If paused Then
                    MIDI_Pause
                Else
                    MIDI_Resume
                End If

            Case KEY_PLUS, KEY_EQUALS
                Volume = Volume + 0.001
                MIDI_SetVolume Volume
                Volume = MIDI_GetVolume

            Case KEY_MINUS, KEY_UNDERSCORE
                Volume = Volume - 0.001
                MIDI_SetVolume Volume
                Volume = MIDI_GetVolume
        End Select

        Limit 60
    Loop Until Not MIDI_IsPlaying Or k = KEY_ESCAPE Or TotalDroppedFiles > 0

    Print: Print "Done!"

    MIDI_Pause

    KeyClear

    Title APP_NAME + " " + OS$ ' Set app title to the way it was
End Sub

' Loops a demo WAV file in the background
' Subsquent calls to this will stop playback
Sub PlayWAV
    Static isPlayed As Byte

    If isPlayed Then
        If Not Sound_Play(Chr$(NULL), FALSE) Then
            Print: Print "Failed to stop backgound sound."
        End If
    Else
        isPlayed = Sound_Play("RAINDROP.wav", TRUE)
        If isPlayed Then
            Print: Print "Looping MP3 compressed RAINDROP.wav..."
        End If
    End If
End Sub

' Processes dropped files one file at a time
Sub ProcessDroppedFiles
    If TotalDroppedFiles > 0 Then
        ' Make a copy of the dropped file and clear the list
        ReDim fileNames(1 To TotalDroppedFiles) As String
        Dim i As Unsigned Long

        For i = 1 To TotalDroppedFiles
            fileNames(i) = DroppedFile(i)
        Next
        FinishDrop ' This is critical

        ' Now play the dropped file one at a time
        For i = LBound(fileNames) To UBound(fileNames)
            PlaySong fileNames(i)
            If TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
        Next
    End If
End Sub


' Processes the command line one file at a time
Sub ProcessCommandLine
    Dim i As Unsigned Long

    For i = 1 To CommandCount
        PlaySong Command$(i)
        If TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
    Next
End Sub
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------
'$Include:'include/FileOps.bas'
'$Include:'include/WinMIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------

