; PlayerInterface CLASS ----------------------------------------------------------

Class PlayerInterface {
	static VLCPasswordInBase64 := VLC_PW_IN_BASE64
	static PlayerType := PLAYER_TYPE
	static ReactionTime := REACTION_TIME

	__New() {
		ShowGUIMessage("GIFER v.'" GIFER_VERSION "' script started.`nPlayer: " PlayerType,,3000)
	}

	status[] {
		get {
			return this.GetPlaybackStatus()
		}
	}

	RetrieveHTTP(URLToGet) {
		oHTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		oHTTP.Open("GET", URLToGet, False)
		; WHR SetCredentials cannot work with empty username (VLC only,
		; MPC WebUI ignores this)
		oHTTP.SetRequestHeader("Authorization", "Basic " VLCPasswordInBase64)
		oHTTP.Send()
		return this.EncodingFix(oHTTP)
	}

	; Makes initial calls to the player's WebUI and passes the response
	; to individual player's handler .UnifyWebUIResponse for unification
	GetPlaybackStatus() {
		KeyPressTime := A_TickCount
		try {
			DecodedStr := this.RetrieveHTTP(this.WebUIUrl)
		} catch e {
			ShowGUIMessage(PlayerType . " or its WebUI is not running!`n" . e, 1, 3000)
			return
		}
		; File operations delay (can reach ~1 sec on the first run)
		Delay := A_TickCount - KeyPressTime
		; personalized function for working with individual players
		PlayerStatus := this.UnifyWebUIResponse(DecodedStr)
		; no corrections when video is paused for precise marking
		If InStr(PlayerStatus["state"], "playing")
			PlayerStatus["position"] -= (ReactionTime + Delay)
		return PlayerStatus
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
