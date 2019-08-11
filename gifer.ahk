; Only works with Media Player Classic and VideoLAN Client (for now).
; Requires ffmpeg.exe from https://ffmpeg.zeranoe.com/builds/ at the %APPDATA% folder.
; Turn on MPC's Web-interface in Options-Player-Web Interface-Listen on port: 13579.
; Obviously, get AutoHotKey @ https://autohotkey.com/download/ and install.
; Put this file anywhere and run it.
; Uses https://github.com/rostok/file2clip for putting clips into windows clipboard
; put file2clip.exe into %APPDATA% if you want this functionality
; Set PLAYERTYPE to match your preferred player (MPC and VLC supported)

; To minimize edits in TRIGGERS section when changes are made
; GLOBAL VARIABLES
global TimeA_ms =
global TimeB_ms =
global FNameA =
global FNameB =

global STARTOFFSET := 0
global FINISHOFFSET := 0
global GIFERVERSION := "8-12 live"

; Has a separate file for storing user settings and hotkeys.
; It must be placed at the same directory with this one.
#include gifer_settings.ahk

if (PLAYERTYPE = "VLC") 
	PlayerHandler := new VLCInterface()
else if (PLAYERTYPE = "MPC") 
	PlayerHandler := new MPCInterface()

; FUNCTIONS -----------------------------------------------------

Class PlayerInterface {
	RetrieveHTTP(URLToGet) {
		oHTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		oHTTP.Open("GET", URLToGet, False)
		; WHR SetCredentials cannot work with empty username (VLC only,
		; MPC WebUI ignores this)
		oHTTP.SetRequestHeader("Authorization", "Basic " VLCPWINBASE64)
		oHTTP.Send()
		return this.EncodingFix(oHTTP)
	}

	; Makes initial calls to the player's WebUI and passes the response
	; to individual player's handler .UnifyWebUIResponse for unification
	GetStatus() {
		KeyPressTime := A_TickCount
		try {
			DecodedStr := this.RetrieveHTTP(this.WebUIUrl)
		} catch e {
			ShowSomeGUI(PLAYERTYPE . " or its WebUI is not running!`n" . e, 1, 3000)
			return
		}
		; File operations delay (can reach ~1 sec on the first run)
		Delay := A_TickCount - KeyPressTime
		; personalized function for working with individual players
		PlayerStatus := this.UnifyWebUIResponse(DecodedStr)
		; no corrections when video is paused for precise marking
		If InStr(PlayerStatus["state"], "playing")
			PlayerStatus["position"] -= (REACTIONTIME + Delay)
		return PlayerStatus
	}

	__New() {
		ShowSomeGUI("GIFER v.'" GIFERVERSION "' script started.`nPlayer: " PLAYERTYPE,,3000)
	}

	status[] {
		get {
			return this.GetStatus()
		}
	}
}

class MPCInterface extends PlayerInterface {
	WebUIUrl := "http://localhost:13579/status.html"

	; hack to force MPC's webUI response to be interpreted as utf-8
	EncodingFix(HTTPObject) {
		pArr := ComObjValue(HTTPObject.ResponseBody)
		cBytes := NumGet(pArr+0, A_PtrSize = 8? 24:16, "uint")
		pText := NumGet(pArr+0, A_PtrSize = 8? 16:12, "ptr")
		httpResponse := StrGet(pText, cBytes, "utf-8")
		return httpResponse
	}

	; converts data relevant for the script into object
	UnifyWebUIResponse(WebUIReply) {
		; converting response syntax to MPC-BE format
		WebUIReply := StrReplace(WebUIReply, """", "'")
		RegExMatch(WebUIReply, "OnStatus\('.*', '(.*)', (\d+), '.*', \d+, '.*', \d+, \d+, '(.*)'\)", MPCStatus)
		AdaptedStatus := { position: MPCStatus2, state: MPCStatus1, fname: MPCStatus3 }
		; msgbox % AdaptedStatus["position"] "`n" AdaptedStatus["state"] "`n" AdaptedStatus["fname"]
		return AdaptedStatus
	}
}

class VLCInterface extends PlayerInterface {
	WebUIUrl := "http://localhost:8080/requests/status.json"

	EncodingFix(HTTPObject) {
		httpResponse := HTTPObject.ResponseText
		return httpResponse
	}

	; VLC returns file name in URI format
	DecodeURI(FileNameInURI) {
	    Try {
	        doc := ComObjCreate("HTMLfile")
	        ; using some ComObj HTMLfile shamanism on the fly...
	        doc.write("<body><script>document.write(decodeURIComponent(""" . FileNameInURI . """));</script>")
	        Return, doc.body.innerText
	    }
	}

	; makes an additional VLC-specific call to WebUI and converts data
	; relevant for the script into object
	UnifyWebUIResponse(WebUIReply) {
		RegExMatch(WebUIReply, ".*""currentplid""\:(\d+).*""length""\:(\d+).*""state""\:""(\w+)"".*""position""\:([\.\d]+).*""filename""\:""(.*?)"".*", Stat)
		
		VLCPlaylist := this.RetrieveHTTP("http://localhost:8080/requests/playlist.json")
		CapString := ".*""name""\:""\Q" Stat5 "\E"",.*?""uri""\:""file:\/\/\/(.*?)"".*}," ;.*?""current"".*"
		RegExMatch(VLCPlaylist, CapString, PL)
		; inverting slashes for path format compatibility
		PL1 := StrReplace(this.DecodeURI(PL1), "/", "\")

		AdaptedStatus := {position: Round(Stat2*1000*Stat4), state: Stat3, fname: PL1}
		return AdaptedStatus
	}
}

ShowSomeGUI(Message, isWarning:=0, Duration:=2000) {
	Gui, Destroy
	CustomColor = 444444 ; Background or transparent color
	Gui +LastFound +AlwaysOnTop -Caption +ToolWindow  ; +ToolWindow avoids a taskbar button and an alt-tab menu item.
	Gui, Color, %CustomColor%
	Gui, Font, s16  ; Set font size (16-point).
	if (isWarning = 0) {
		If (PLAYERTYPE = "VLC")
			Gui, Add, Text, c0feeeb, % Message 
		else
			Gui, Add, Text, cLime, % Message 
	}
	Else
		Gui, Add, Text, cRed, % Message 
	WinSet, Transparent, 170 ; can be TransColor, %CustomColor% for transparent BG
	Gui, Show, x0 y0 NoActivate  ; NoActivate avoids deactivating the currently active window.
	Sleep, Duration
	Gui, Hide
	Gui, Destroy
	Return
}

; lurk for separate subtitle files within input video folder
; if none found, set the command to try extracting them from video file
GetSubSource(FName, MarkA, MarkB) {
	SubFile := RegexReplace(FName, "\.[\w\d]+$", ".srt")
	AssFile := RegexReplace(FName, "\.[\w\d]+$", ".ass")
	FrameRate := FORCEFRATE
	; checking whether .srt or .ass file with the same name as the video exists in the same directory
	if FileExist(SubFile) 
		SubExtractCMD := % """" FFMPEGEXE """ -ss " MarkA " -t " MarkB-MarkA " -i """ SubFile """ -t " MarkB-MarkA " """ TEMPSUBFILE """ 2>> """ FFMPEGLOG """"
	else if FileExist(AssFile) 
		SubExtractCMD := % """" FFMPEGEXE """ -ss " MarkA " -t " MarkB-MarkA " -i """ AssFile """ -t " MarkB-MarkA " """ TEMPSUBFILE """ 2>> """ FFMPEGLOG """"
	else 
		SubExtractCMD := % """" FFMPEGEXE """ -ss " MarkA " -t " MarkB-MarkA FrameRate " -i """ FName """ -map 0:s:0 -t " MarkB-MarkA " """ TEMPSUBFILE """ 2>> """ FFMPEGLOG """"
	;msgbox % SubExtractCMD
	return SubExtractCMD
}

; Mode 0 - video only, 1 - with subs, 2 - with subs and sound
EncodeStuff(Mode) {
	TimeA := TimeA_ms/1000
	TimeB := TimeB_ms/1000

	SplitPath, FNameA, FNameShort, FNameDir
	NewVideoName := PrepareClipName(FNameShort) ".mp4"
	if (CLIPFOLDER = "")
		NewVideoFull := FNameDir "\" NewVideoName
	else
		NewVideoFull := CLIPFOLDER NewVideoName
	FileDelete, %FFMPEGLOG%
	; start forming FFMPEG parameters string according to requested mode
	FfmpegParams := FFMPEGDEFAULT

	if (Mode >= 1) {
		SubExtractCMD := GetSubSource(FNameA, TimeA, TimeB)
		FileDelete, %TEMPSUBFILE%
		FileAppend, %SubExtractCmd% `n, %FFMPEGLOG%
		RunWait, % ComSpec " /c """ SubExtractCmd """", %A_AppData%, Hide
		FileGetSize, SubFileSize, %TEMPSUBFILE%
		; checking whether there actually are some subs available during our interval
		if (ErrorLevel or SubFileSize = 0)
			ShowSomeGUI("No subtitles are available for this clip!`nEncoding without subs...",1)
		else {
			; removing additional font tags from subs
			FileRead, SubContents, %TEMPSUBFILE%
	        SubContents := RegExReplace(SubContents, "<.*?>")
			SubFile := FileOpen(TEMPSUBFILE, "w")
			SubFile.Write(SubContents)
			SubFile.Close()
			FfmpegParams := FFMPEGWSUBS
		}
	}
	if (Mode < 2)
		; no audio stream option
		FfmpegParams := " -an " FfmpegParams
	Else
		FfmpegParams := FFMPEGSOUND FfmpegParams
	;msgbox % FfmpegParams "`n" 

	; all full paths passed by variables should be enclosed with "" 
	FrameRate := FORCEFRATE
	EncodeCMD := % """" FFMPEGEXE """ -nostdin -ss " TimeA " -t " TimeB-TimeA " -i """ FNameA """ " FrameRate FfmpegParams " -t " TimeB-TimeA " """ NewVideoFull """ 2>> """ FFMPEGLOG """"
	FileAppend, %EncodeCMD% `n, %FFMPEGLOG%
	ShowSomeGUI("Encoding started...")
	; whole command string must be enclosed with double quotes as well
	RunWait, % ComSpec " /c """ EncodeCMD """", %A_AppData%, Hide
	if (not ErrorLevel and FileExist(CLIPBOARDUTIL)){
		; copying clip into clipboard via file2clip
		ClipCmd := CLIPBOARDUTIL " """ NewVideoFull """"
		RunWait, % ComSpec " /c """ ClipCmd """", %A_AppData%, Hide
		ShowSomeGUI("Clip saved to: " NewVideoFull "`n-> Clipboard")
	}
	else if not ErrorLevel
		ShowSomeGUI("Clip saved to: " NewVideoFull)
	Else
		ShowSomeGUI("Could not encode the video!",1)
	return
}

MakeMarkA(PlayerHandler) {
	PlayerStatus := PlayerHandler.status
	if not PlayerStatus
		return
	TimeA_ms := PlayerStatus["position"] + STARTOFFSET
	FNameA := PlayerStatus["fname"] 

	ShowSomeGUI("Start point: " FNameA "`n" TimeA_ms/1000 " sec")	
	return
}

MakeMarkB(PlayerHandler) {
	PlayerStatus := PlayerHandler.status
	if not PlayerStatus
		return
	TimeB_ms := PlayerStatus["position"] + FINISHOFFSET
	FNameB := PlayerStatus["fname"]
	
	ShowSomeGUI("End point: " FNameB "`n" TimeB_ms/1000 " sec")
	return	
}

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
	MsgBox % GIFERVERSION "`n" PLAYERTYPE "`n" TimeA_ms "`n" TimeB_ms "`n" FNameA "`n" FNameB "`n" PrepareClipName("test.mp4") ;FNameShort "`n"
	clipboard := GIFERVERSION "`n" PLAYERTYPE "`n" TimeA_ms "`n" TimeB_ms "`n" FNameA "`n" FNameB "`n" PrepareClipName("test.mp4")
	; some debug stuff will be here I guess
return

^!r::
	Reload
	Sleep 1000 
	MsgBox, The script could not be reloaded.
return

; start marker
MarkStart:
	MakeMarkA(PlayerHandler)
Return

; end marker
MarkFinish:
	MakeMarkB(PlayerHandler)
Return

; check and encode
EncodeClean:
	if (TimeA_ms < TimeB_ms and FNameA = FNameB)
		EncodeStuff(0)
	Else {
		ShowSomeGUI("Something went wrong... Reselect start and end points!",1)
		CleanUp()
	}
Return

; check and encode WITH HARDSUBS, currently has known problems with .OGM format
EncodeSubs:
	if (TimeA_ms < TimeB_ms and FNameA = FNameB)
		;msgBox % TimeA_ms "`n" TimeB_ms "`n" FNameA "`n" FNameB
		EncodeStuff(1)
	Else {
		ShowSomeGUI("Something went wrong... Reselect start and end points!",1)
		CleanUp()
	}
Return


; check and encode WITH SOUND AND HARDSUBS, currently has known problems with .OGM format
EncodeSound:
	if (TimeA_ms < TimeB_ms and FNameA = FNameB)
		;msgBox % TimeA_ms "`n" TimeB_ms "`n" FNameA "`n" FNameB
		EncodeStuff(2)
	Else {
		ShowSomeGUI("Something went wrong... Reselect start and end points!",1)
		CleanUp()
	}
Return