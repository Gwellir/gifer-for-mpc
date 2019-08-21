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
global TimeA_ms =
global TimeB_ms =
global FNameA =
global FNameB =

global START_OFFSET := 0
global FINISH_OFFSET := 0
global GIFER_VERSION := "9.1 testing"

; Has a separate file for storing user settings and hotkeys.
; It must be placed at the same directory with this one.
#include gifer_settings.ahk
#include gifer_player_interface.ahk
#include gifer_encoder_interface.ahk

SetWorkingDir, %WORK_FOLDER%

if (PLAYER_TYPE = "VLC") 
	PlayerHandler := new VLCInterface()
else if (PLAYER_TYPE = "MPC") 
	PlayerHandler := new MPCInterface()

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
	SetTimer, KillPopup, %Duration%
	Return
}

; Mode 0 - video only, 1 - with subs, 2 - with subs and sound
EncodeMP4(Mode, ClipFolder, ClipboardUtil) {
	TimeA := TimeA_ms/1000
	TimeB := TimeB_ms/1000

	SplitPath, FNameA, FNameShort, FNameDir
	newVideoName := PrepareClipName(FNameShort) ".mp4"
	if (ClipFolder = "")
		newVideoFull := FNameDir "\" newVideoName
	else
		newVideoFullName := ClipFolder newVideoName

	ShowGUIMessage("Encoding started...")
	try {
		EncoderInterface.encode(mode, newVideoFullName, FNameA, TimeA, TimeB)
		if (FileExist(ClipboardUtil)) {
			; copying clip into clipboard via file2clip
			ClipCmd := CLipboardUtil " """ newVideoFullName """"
			RunWait, % ComSpec " /c """ ClipCmd """", %A_AppData%, Hide
			ShowGUIMessage("Clip saved to: " newVideoFullName "`n-> Clipboard")
		} 
		else 
			ShowGUIMessage("Clip saved to: " newVideoFullName)
	}
	catch e {
		ShowGUIMessage("Could not encode the video!",1)
	}
	return
}

MakeMarkA(PlayerHandler) {
	PlayerStatus := PlayerHandler.status
	if not PlayerStatus
		return
	;to objectify
	TimeA_ms := PlayerStatus["position"] + START_OFFSET
	FNameA := PlayerStatus["fname"] 

	ShowGUIMessage("Start point: " FNameA "`n" TimeA_ms/1000 " sec")	
	return
}

MakeMarkB(PlayerHandler) {
	PlayerStatus := PlayerHandler.status
	if not PlayerStatus
		return
	;to objectify
	TimeB_ms := PlayerStatus["position"] + FINISH_OFFSET
	FNameB := PlayerStatus["fname"]
	
	ShowGUIMessage("End point: " FNameB "`n" TimeB_ms/1000 " sec")
	return	
}

;to objectify
CleanUp() {
	TimeA_ms =
	TimeB_ms =
	FNameA =
	FNameB =
	return
}

; TRIGGERED -----------------------------------------------------

^!q::
Debug:
	MsgBox % GIFER_VERSION "`n" PLAYER_TYPE "`n" TimeA_ms "`n" TimeB_ms "`n" FNameA "`n" FNameB "`n" PrepareClipName("test.mp4") ;FNameShort "`n"
	clipboard := GIFER_VERSION "`n" PLAYER_TYPE "`n" TimeA_ms "`n" TimeB_ms "`n" FNameA "`n" FNameB "`n" PrepareClipName("test.mp4")
	; some debug stuff will be here I guess
return

^!r::
	Reload
	Sleep 1000 
	;MsgBox, The script could not be reloaded.
return

; start marker
MarkStart:
	MakeMarkA(PlayerHandler)
Return

; end marker
MarkFinish:
	MakeMarkB(PlayerHandler)
Return

KillPopup:
	Gui, Hide
	Gui, Destroy
Return

; check and encode
EncodeClean:
	if (TimeA_ms < TimeB_ms and FNameA = FNameB)
		EncodeMP4(0, CLIP_FOLDER, CLIPBOARD_UTIL)
	Else {
		ShowGUIMessage("Something went wrong... Reselect start and end points!",1)
		CleanUp()
	}
Return

; check and encode WITH HARDSUBS, currently has known problems with .OGM format
EncodeSubs:
	if (TimeA_ms < TimeB_ms and FNameA = FNameB)
		EncodeMP4(1, CLIP_FOLDER, CLIPBOARD_UTIL)
	Else {
		ShowGUIMessage("Something went wrong... Reselect start and end points!",1)
		CleanUp()
	}
Return


; check and encode WITH SOUND AND HARDSUBS, currently has known problems with .OGM format
EncodeSound:
	if (TimeA_ms < TimeB_ms and FNameA = FNameB)
		EncodeMP4(2, CLIP_FOLDER, CLIPBOARD_UTIL)
	Else {
		ShowGUIMessage("Something went wrong... Reselect start and end points!",1)
		CleanUp()
	}
Return