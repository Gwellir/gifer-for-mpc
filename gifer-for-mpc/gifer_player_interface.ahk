; PlayerInterface CLASS ----------------------------------------------------------

Class PlayerInterface {
	static ReactionTime := REACTION_TIME

	__New() {
		this.PlayerType := PLAYER_TYPE
		ShowGUIMessage("GIFER v.'" GIFER_VERSION "' script started.`nPlayer: " this.PlayerType ,,3000)
	}

	status[] {
		get {
			return this.GetPlaybackStatus()
		}
	}

	; Makes initial calls to the player's WebUI and passes the response
	; to individual player's handler .UnifyWebUIResponse for unification
	GetPlaybackStatus() {
		keyPressTime := A_TickCount
		try {
			decodedStr := this.RetrieveHTTP(this.webUIUrl)
		} catch e {
			ShowGUIMessage(this.PlayerType . " or its WebUI is not running!`n" . e, 1, 3000)
			return
		}
		; File operations delay (can reach ~1 sec on the first run)
		delay := A_TickCount - keyPressTime
		; personalized function for working with individual players
		PlayerStatus := this.UnifyWebUIResponse(decodedStr)
		; no corrections when video is paused for precise marking
		If InStr(PlayerStatus["state"], "playing")
			PlayerStatus["position"] -= (ReactionTime + delay)
		return PlayerStatus
	}
}

class MPCInterface extends PlayerInterface {
	webUIUrl := "http://localhost:13579/status.html"
	tempStatusFile := TEMP_STATUS_FILE

	RetrieveHTTP(URLToGet) {
		if FileExist(this.tempStatusFile)
			FileDelete, % this.tempStatusFile
		try UrlDownloadToFile, % this.webUIUrl, % this.tempStatusFile
		catch Err {
			Throw, "Can't get MPC status!"
			return
		}
		FileRead, decodedStr, % *P65001 this.tempStatusFile ; *P65001 enforces reading as UTF
			return decodedStr
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
	VLCPasswordInBase64 := VLC_PW_IN_BASE64

	RetrieveHTTP(URLToGet) {
		oHTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		oHTTP.Open("GET", URLToGet, False)
		; WHR SetCredentials cannot work with empty username (VLC only,
		; MPC WebUI ignores this)
		oHTTP.SetRequestHeader("Authorization", "Basic " this.VLCPasswordInBase64)
		oHTTP.Send()
		return oHTTP.ResponseText
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
