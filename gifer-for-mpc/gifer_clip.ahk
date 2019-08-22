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
			return {startPos: this.startPos, sourceFile: this.sourceFile, mode: this.mode, duration: this.duration, clipFile: this.clipFile}
		} }
		
; NO GLOBALS BELOW THIS LINE --------------------------------------------------

	__New(startPos:=0, endPos:=0, sourceFile:="", mode:=0) {
		this.startPos := startPos
		this.endPos := endPos
		this.sourceFile := sourceFile
		this.mode := mode
	}

	setStart(startPos, sourceFile) {
		this.startPos := startPos
		if (sourceFile != this.sourceFile) {
			this.sourceFile := sourceFile
			this.endPos := startPos
		}
		ShowGUIMessage(format("Start point: {1}`n{2:0.1f} sec", this.sourceFile, this.startPos))	
	}

	setEnd(endPos, sourceFile) {
		this.endPos := endPos
		if (sourceFile != this.sourceFile) {
			this.sourceFile := sourceFile
			this.startPos := endPos
		}
		ShowGUIMessage(format("End point: {1}`n{2:0.1f} sec", this.sourceFile, this.endPos))	
	}

	; Mode 0 - video only, 1 - with subs, 2 - with subs and sound
	encodeClip(mode) {
		if ((this.duration > 0) and (this.sourceFile != "") and (mode == 0 or mode == 1 or mode == 2)) {
			this.mode := mode
			this.prepareClipPath()
			ShowGUIMessage("Encoding started...")
			try {
				EncoderInterface.encode(this.clipParams)
				this.storeInClipboard()
			} catch e { 
				ShowGUIMessage("Could not encode the video!",1)
			}
		}
		Else {
			ShowGUIMessage("Something went wrong... One of the points may not have been selected!",1)
		}
	}

	prepareClipPath() {
		SplitPath, % this.sourceFile , fNameShort, fNameDir
		newClipName := PrepareClipName(fNameShort, round(this.startPos*1000), round(this.endPos*1000), this.mode) ".mp4"
		if (ClipHandler.clipFolder = "")
			this.clipFile := FNameDir "\" newClipName
		else
			this.clipFile := ClipHandler.clipFolder newClipName
	}

	storeInClipboard() {
		if (FileExist(ClipHandler.clipboardUtil)) {
			; copying clip into clipboard via file2clip
			ClipCmd := ClipHandler.clipboardUtil " """ this.clipFile """"
			RunWait, % ComSpec " /c """ ClipCmd """", %A_AppData%, Hide
			ShowGUIMessage("Clip saved to: " this.clipFile "`n-> Clipboard")
		} 
		else 
			ShowGUIMessage("Clip saved to: " this.clipFile)
	}
}