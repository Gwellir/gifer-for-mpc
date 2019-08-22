; Separate file of a "gifer" MP4 short clip maker AHK script.
; Should be put in the same directory as the main script.
; Contains global constants which store primary configurable
; settings alongside hotkeys and some functions to preserve them
; during main script edits.

; PRESETS 	-------------------------------------------------------------------

Menu, Tray, Icon, %A_WinDir%\system32\shell32.dll,224

; PLAYER PARAMETERS -----------------------------------------------------------
global PLAYER_TYPE := "MPC" ; "MPC"|"VLC" - CHECK THE COMMENT FOR VLC_PW_IN_BASE64 IF USING VLC

; this is ":12345" encoded with base64. Don't ask. Just don't.
; Do set your VLC web-interface password to "12345" though.
global VLC_PW_IN_BASE64 := "OjEyMzQ1" ; VLC-only option

; in milliseconds, adjustment for reaction time when making markers while video is being played, you can tune it to your taste
global REACTION_TIME := 400

; manually set permanent marker offsets (in milliseconds)
; for start and finish of selected interval
; positive value moves marker closer to the end of file
global START_OFFSET := 0
global FINISH_OFFSET := 0

; ENCODER PARAMETERS ----------------------------------------------------------
global CLIP_WIDTH := 800
global CLIP_QUALITY := 28 ; 18 to 28, lower is better
; CLI parameters and patterns which are more specific to the encoder
; are stored in the Ffmpeg Class (gifer_encoder_interface.ahk)

; FILE PATH PARAMETERS --------------------------------------------------------
; set CLIPFOLDER to "" to put clips into the same folder as source video
global CLIP_FOLDER := "%USERPROFILE%\Videos\"
global WORK_FOLDER := A_AppData "\gifer-for-mpc"
global TEMP_SUB_FILE := "temp_subs.ass"
global CLIPBOARD_UTIL := WORK_FOLDER "\file2clip.exe"
global TEMP_STATUS_FILE := WORK_FOLDER "\mpc_status.html"

; HOTKEYS   -------------------------------------------------------------------

; start marker
Hotkey % "^!+a", MarkStart ; CTRL(^) ALT(!) SHIFT(+) a
Hotkey % "^#LButton", MarkStart ; CTRL WIN(#) LMB Press

; end marker
Hotkey % "^!+s", MarkEnd ; CTRL ALT SHIFT s
Hotkey % "^#LButton UP", MarkEnd ; CTRL WIN LMB Release

; check and encode
Hotkey % "^!+z", EncodeClean ; CTRL ALT SHIFT z
Hotkey % "^#RButton", EncodeClean ; CTRL WIN RMB

; check and encode WITH HARDSUBS, currently has known problems with .OGM format
Hotkey % "^!+x", EncodeSubs ; CTRL ALT SHIFT x
Hotkey % "^#!RButton", EncodeSubs ; CTRL WIN ALT RMB

; check and encode WITH SOUND AND HARDSUBS, currently has known problems with .OGM format
Hotkey % "^!+c", EncodeSound ; CTRL ALT SHIFT c
Hotkey % "^#!Space", EncodeSound ; CTRL WIN ALT Space

; GENERATORS ------------------------------------------------------------------

PrepareClipName(InputFileName, startPos, endPos, mode) { 
	; removing all symbols which are not rus/eng alphabetic, numeric or these: "._[]- " from the clip name
	ClipBaseName := RegexReplace(RegexReplace(InputFileName, "\.[\d\w]+?$", ""), "[^a-zA-Zа-яА-Я0-9_\.\[\] -]", "")
	; adding prefix and suffix before returning, no extension required
	; https://autohotkey.com/docs/Variables.htm#date A_* vars reference
	nameParams := [ClipBaseName, startPos, endPos, mode]
	return format("{1}_[{2}_{3}]_{4}", nameParams*)
	
	; EXAMPLE (monthly folders) will save videos in different subfolders, i.e. \2019-08\ each month 
	; nameParams := [A_YYYY, A_MM, CLipBaseName, startPos//1000, endPos//1000, mode]
	; return format("{1}-{2}\{3}_[{4}_{5}]_{6}", nameParams*)
}

;#include *i gifer_experimental.ahk