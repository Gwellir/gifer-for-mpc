; CLIP HANDLING CLASS ---------------------------------------------------------

Class ClipHandler {
	clipFolder {
		get {
			return CLIP_FOLDER
		} }
	clipboardUtil {
		get { 
			return CLIPBOARD_UTIL
		} }
	duration { 
		get {
			return this.endPos - this.startPos
		} }
	clipParams {
		get {
			return {startPos: this.startPos, fName: this.fName, mode: this.mode, duration: this.duration}
		} }
		
; NO GLOBALS BELOW THIS LINE --------------------------------------------------

	__New(startPos:=0, endPos:=0, fName:="", mode:=0) {
		this.startPos := startPos
		this.endPos := endPos
		this.fName := fName
		this.mode := mode
	}

	setStart(startPos, fName) {
		this.startPos := startPos
		if (fName != this.fName) {
			this.fName := fName
			this.endPos := startPos
		}
		ShowGUIMessage(format("Start point: {1}`n{2:0.1f} sec", this.fName, this.startPos))	
	}

	setEnd(endPos, fName) {
		this.endPos := endPos
		if (fName != this.fName) {
			this.fName := fName
			this.startPos := endPos
		}
		ShowGUIMessage(format("End point: {1}`n{2:0.1f} sec", this.fName, this.endPos))	
	}

	; Mode 0 - video only, 1 - with subs, 2 - with subs and sound
	encodeClip(mode) {
		if ((this.duration > 0) and (this.fName != "") and (mode == 0 or mode == 1 or mode == 2)) {
			this.mode := mode
			newVideoFullName := this.prepareClipPath()
			ShowGUIMessage("Encoding started...")
			try {
				EncoderInterface.encode(newVideoFullName, this.clipParams)
				this.storeInClipBoard(newVideoFullName)
			} catch e { 
				ShowGUIMessage("Could not encode the video!",1)
			}
		}
		Else {
			ShowGUIMessage("Something went wrong... One of the points may not have been selected!",1)
		}
	}

	prepareClipPath() {
		SplitPath, % this.fName , fNameShort, fNameDir
		newVideoName := PrepareClipName(fNameShort, round(this.startPos*1000), round(this.endPos*1000), this.mode) ".mp4"
		if (ClipHandler.clipFolder = "")
			newVideoFullName := FNameDir "\" newVideoName
		else
			newVideoFullName := ClipHandler.clipFolder newVideoName
		return newVideoFullName
	}

	storeInClipBoard(newVideoFullName) {
		if (FileExist(ClipHandler.clipboardUtil)) {
			; copying clip into clipboard via file2clip
			ClipCmd := ClipHandler.clipboardUtil " """ newVideoFullName """"
			RunWait, % ComSpec " /c """ ClipCmd """", %A_AppData%, Hide
			ShowGUIMessage("Clip saved to: " newVideoFullName "`n-> Clipboard")
		} 
		else 
			ShowGUIMessage("Clip saved to: " newVideoFullName)
	}
}