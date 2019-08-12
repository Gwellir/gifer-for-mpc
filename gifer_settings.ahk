﻿; Separate file of a "gifer" MP4 short clip maker AHK script.
; Should be put in the same directory as the main script.
; Contains global constants which store primary configurable
; settings alongside hotkeys and some functions to preserve them
; during main script edits.

; PRESETS 	-------------------------------------------------------------------

Menu, Tray, Icon, %A_WinDir%\system32\shell32.dll,224

; PLAYER PARAMETERS -----------------------------------------------------------
global PLAYER_TYPE := "MPC" ; "MPC"|"VLC"

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
; EDITED vvvvvvvvvvv - framerate 24000/1001 fps
; you can set this option to "" to use file's framerate but there will be unpredictable
; glitches with some codec/container combinations, or if input video has variable framerate
global FORCE_FRATE := " -r ntsc-film " ; for compatibility use

; no subtitle tracks, 8-bit color, rescale to make pixels square, width 800px or native if it's lower, height dividable by 2,
; worst recommended h264 quality (28, lower is better, down to 18), encode with libx264
global FFMPEG_DEFAULT := " -sn -pix_fmt yuv420p -vf ""scale=iw*sar:ih, scale='min(800,iw)':-2"" -crf 28 -c:v libx264 "

; everything else should be obvious, while PrimaryColour format is &H<2-symbol hexcode for transparency level><BBGGRR color hex code>
; any ASS style fields https://pastebin.com/80yDaaRF should be usable under 'force_style' parameter
global SUB_FORMAT := ".ass" ; .ass|.srt, srt sometimes has troubles with timing

global FFMPEG_WSUBS := " -sn -pix_fmt yuv420p -vf ""[in]scale=iw*sar:ih, scale='min(800,iw)':-2, subtitles=temp_subs" SUB_FORMAT ":force_style='FontName=Open Sans Semibold,FontSize=45,PrimaryColour=&H00FFFFFF,Bold=1'"" -crf 28 -c:v libx264 " 

; " -c:a copy " should be usable for 95% cases probably, like all HS ongoing releases
; " -c:a aac -b:a 128k -ac 2 " will recode audio to AAC 128kbit/s stereo
; (in case of 5.1 stuff or awkward codecs)
global FFMPEG_SOUND := " -c:a aac -b:a 128k -ac 2 "

; FILE PATH PARAMETERS --------------------------------------------------------
; set CLIPFOLDER to "" to put clips into the same folder as source video
global CLIP_FOLDER := "%USERPROFILE%\Videos\"
global WORK_FOLDER := A_AppData "\gifer-for-mpc"
global FFMPEG_EXE := WORK_FOLDER "\ffmpeg.exe"
global FFMPEG_LOG := WORK_FOLDER "\ffmpeg_gifer.log"
global TEMP_SUB_FILE := WORK_FOLDER "\temp_subs" SUB_FORMAT
global CLIPBOARD_UTIL := WORK_FOLDER "\file2clip.exe"
global TEMP_STATUS_FILE := WORK_FOLDER "\mpc_status.html"

; HOTKEYS   -------------------------------------------------------------------

; start marker
Hotkey % "^!+a", MarkStart ; CTRL(^) ALT(!) SHIFT(+) a
Hotkey % "^#LButton", MarkStart ; CTRL WIN(#) LMB Press

; end marker
Hotkey % "^!+s", MarkFinish ; CTRL ALT SHIFT s
Hotkey % "^#LButton UP", MarkFinish ; CTRL WIN LMB Release

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

PrepareClipName(InputFileName) { 
	; removing all symbols which are not rus/eng alphabetic, numeric or these: "._[]- " from the clip name
	ClipBaseName := RegexReplace(RegexReplace(InputFileName, "\.[\d\w]+?$", ""), "[^a-zA-Zа-яА-Я0-9_\.\[\] -]", "")
	; adding prefix and suffix before returning, no extension required
	; https://autohotkey.com/docs/Variables.htm#date A_* vars reference
	;return ClipBaseName "_[" A_YYYY A_MM A_DD "]_" SubStr(A_TickCount, -2)
	return ClipBaseName "_[" TimeA_ms "_" TimeB_ms "]_" 
}

;#include *i gifer_experimental.ahk