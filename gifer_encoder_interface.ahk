; EncoderInterface CLASS ----------------------------------------------------------

Class EncoderInterface {
	; parameters corresponding to the encoder (ffmpeg) options
	c_forceFrate() {
		return FORCE_FRATE
	}
	c_ffmpegDefault() {
		return FFMPEG_DEFAULT
	}
	c_ffmpegWsubs() {
		return FFMPEG_WSUBS
	}
	c_ffmpegSound() {
		return FFMPEG_SOUND
	}
	c_ffmpegExe() {
		return FFMPEG_EXE
	}
	c_ffmpegLog() {
		return FFMPEG_LOG
	}
	c_tempSubFile() {
		return TEMP_SUB_FILE
	}
	
	encode(mode, newVideoFullName, sourceVideoFile, markA, markB) {
		ffmpegParams := this.prepareEncodingParameters(mode, sourceVideoFile, markA, markB)
		encodeCMD := this.getEncodingCommand(ffmpegParams, newVideoFullName, sourceVideoFile, markA, markB)
		FileAppend, ==ENCODE==`n %encodeCMD% `n, % this.c_ffmpegLog()

		; whole command string must be enclosed with double quotes as well
		RunWait, % ComSpec " /c """ encodeCMD """", %A_AppData%, Hide
		if (ErrorLevel)
			throw ErrorLevel
	}

	getEncodingCommand(ffmpegParams, newVideoFullName, sourceVideoFile, markA, markB) {
		; all full paths passed by variables should be enclosed with "" 
		return % """" this.c_ffmpegExe() """ -nostdin -ss " markA " -t " markB-markA " -i """ sourceVideoFile """ " this.c_forceFrate() ffmpegParams " -t " markB-markA " """ newVideoFullName """ 2>> """ this.c_ffmpegLog() """"
	}

	prepareEncodingParameters(mode, sourceVideoFile, markA, markB) {
		if (FileExist(this.c_ffmpegLog())) {
			FileDelete, % this.c_ffmpegLog()
		}
		; start forming FFMPEG parameters string according to requested mode
		ffmpegParams := this.c_ffmpegDefault()
		
		if (mode >= 1) {
			subExtractCMD := this.getSubSource(sourceVideoFile, markA, markB)
			if (FileExist(this.c_tempSubFile()))
				FileDelete, % this.c_tempSubFile()
			FileAppend, ==SUBS==`n %subExtractCMD% `n, % this.c_ffmpegLog()
			RunWait, % ComSpec " /c """ subExtractCMD """", %A_AppData%, Hide
			FileGetSize, subFileSize, % this.c_tempSubFile()
			; checking whether there actually are some subs available during our interval
			if (ErrorLevel or subFileSize = 0)
				ShowGUIMessage("No subtitles are available for this clip!`nWill encode without subs...",1)
			else {
				; removing additional font tags from subs
				FileRead, subContents, % this.c_tempSubFile()
		        subContents := RegExReplace(subContents, "<.*?>")
				subFile := FileOpen(this.c_tempSubFile(), "w")
				subFile.Write(subContents)
				subFile.Close()
				ffmpegParams := this.c_ffmpegWsubs()
			}
		}
		if (mode < 2)
			; no audio stream option
			ffmpegParams := " -an " ffmpegParams
		Else
			ffmpegParams := this.c_ffmpegSound() ffmpegParams
		return ffmpegParams
	}

	; lurk for separate subtitle files within input video folder
	; if none found, set the command to try extracting them from video file
	getSubSource(sourceVideoFile, markA, markB) {
		subFile := RegexReplace(sourceVideoFile, "\.[\w\d]+$", ".srt")
		assFile := RegexReplace(sourceVideoFile, "\.[\w\d]+$", ".ass")
		; checking whether .srt or .ass file with the same name as the video exists in the same directory
		if FileExist(subFile) 
			subExtractCMD := EncoderInterface.getSubExtractCommand(markA, markB, SubFile)
		else if FileExist(assFile) 
			subExtractCMD := EncoderInterface.getSubExtractCommand(markA, markB, AssFile)
		else 
			subExtractCMD := EncoderInterface.getInnateSubExtractCommand(markA, markB, sourceVideoFile)
		return subExtractCMD
	}

	getSubExtractCommand(markA, markB, subFile) {
		return % """" this.c_ffmpegExe() """ -ss " markA " -t " markB-markA " -i """ subFile """ -t " markB-markA " """ this.c_tempSubFile() """ 2>> """ this.c_ffmpegLog() """"
	}

	getInnateSubExtractCommand(markA, markB, videoFile) {
		return % """" this.c_ffmpegExe() """ -ss " markA " -t " markB-markA this.c_forceFrate() " -i """ videoFile """ -map 0:s:0 -t " markB-markA " """ this.c_tempSubFile() """ 2>> """ this.c_ffmpegLog() """"
	}
}
