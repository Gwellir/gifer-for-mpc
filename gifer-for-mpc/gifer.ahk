; Only works with Media Player Classic and VideoLAN Client (for now).
; Requires ffmpeg.exe from https://ffmpeg.zeranoe.com/builds/ at the %APPDATA% folder.
; Turn on MPC's Web-interface in Options-Player-Web Interface-Listen on port: 13579.
; Obviously, get AutoHotKey @ https://autohotkey.com/download/ and install.
; Put this file anywhere and run it.
; Uses https://github.com/rostok/file2clip for putting clips into windows clipboard
; put file2clip.exe into %APPDATA% if you want this functionality
; Set PLAYER_TYPE to match your preferred player (MPC and VLC supported)

; To minimize edits in TRIGGERS section when changes are made
; GLOBAL VARIABLES
global START_OFFSET := 0
global FINISH_OFFSET := 0
global GIFER_VERSION := "9.1 testing"

; Has a separate file for storing user settings and hotkeys.
; It must be placed at the same directory with this one.
#include gifer_settings.ahk
#include gifer_player_interface.ahk
#include gifer_encoder_interface.ahk
#include gifer_clip.ahk

SetWorkingDir, %WORK_FOLDER%

if (PLAYER_TYPE = "VLC") 
	PlayerHandler := new VLCInterface()
else if (PLAYER_TYPE = "MPC") 
	PlayerHandler := new MPCInterface()

currentClip := new ClipHandler()

; FUNCTIONS -----------------------------------------------------

ShowGUIMessage(Message, isWarning:=0, Duration:=2000) {
	Gui, Destroy
	CustomColor = 444444 ; Background or transparent color
	Gui +LastFound +AlwaysOnTop -Caption +ToolWindow  ; +ToolWindow avoids a taskbar button and an alt-tab menu item.
	Gui, Color, %CustomColor%
	Gui, Font, s16  ; Set font size (16-point).
	if (isWarning = 0) {
		if (PLAYER_TYPE = "VLC")
			Gui, Add, Text, c0feeeb, % Message 
		else
			Gui, Add, Text, cLime, % Message 
	}
	else
		Gui, Add, Text, cRed, % Message 
	WinSet, Transparent, 170 ; can be TransColor, %CustomColor% for transparent BG
	Gui, Show, x0 y0 NoActivate  ; NoActivate avoids deactivating the currently active window.
	SetTimer, KillGuiPopup, %Duration%
	Return
}

; TRIGGERED -----------------------------------------------------

^!q::
Debug:
	MsgBox % GIFER_VERSION "`n" PlayerHandler.PlayerType "`n" currentClip.startPos "`n" currentClip.endPos "`n" currentClip.fName "`n" PrepareClipName("test.mp4",0,0,0) ;FNameShort "`n"
	clipboard := GIFER_VERSION "`n" PlayerHandler.PlayerType "`n" currentClip.startPos "`n" currentClip.endPos "`n" currentClip.fName "`n" PrepareClipName("test.mp4",0,0,0)
	; some debug stuff will be here I guess
return

^!r::
	Reload
	Sleep 1000 
	;MsgBox, The script could not be reloaded.
return

; start marker
MarkStart:
	PlayerStatus := PlayerHandler.status
	if not PlayerStatus
		return
	currentClip.setStart((PlayerStatus.position + START_OFFSET)/1000, PlayerStatus.fName)
Return

; end marker
MarkEnd:
	PlayerStatus := PlayerHandler.status
	if not PlayerStatus
		return
	currentClip.setEnd((PlayerStatus.position + FINISH_OFFSET)/1000, PlayerStatus.fName)
Return

KillGuiPopup:
	Gui, Hide
	Gui, Destroy
Return

; check and encode
EncodeClean:
	currentClip.encodeClip(0)
Return

; check and encode WITH HARDSUBS, currently has known problems with .OGM format
EncodeSubs:
	currentClip.encodeClip(1)
Return


; check and encode WITH SOUND AND HARDSUBS, currently has known problems with .OGM format
EncodeSound:
	currentClip.encodeClip(2)
Return