; EncoderInterface CLASS ----------------------------------------------------------

Class EncoderInterface {
	; wrappers for parameters corresponding to the encoder (ffmpeg) options
	c_forceFrate {
		get {
			return FORCE_FRATE
		}
	}
	c_ffmpegDefault {
		get {
			return FFMPEG_DEFAULT
		}
	}
	c_ffmpegWsubs {
		get {
			return FFMPEG_WSUBS
		}
	}
	c_ffmpegSound {
		get {
			return FFMPEG_SOUND
		}
	}
	c_ffmpegExe {
		get {
			return FFMPEG_EXE
		}
	}
	c_ffmpegLog {
		get {
			return FFMPEG_LOG
		}
	}
	c_tempSubFile {
		get {
			return TEMP_SUB_FILE
		}
	}

	; NO GLOBALS BELOW THIS LINE ----------------------------------------------
	
	encode(mode, newVideoFullName, sourceVideoFile, markA, markB) {
		ffmpegParams := this.prepareEncodingParameters(mode, sourceVideoFile, markA, markB)
		encodeCMD := this.getEncodingCommand(ffmpegParams, newVideoFullName, sourceVideoFile, markA, markB)
		FileAppend, ==ENCODE==`n %encodeCMD% `n, % this.c_ffmpegLog

		; whole command string must be enclosed with double quotes as well
		; WARNING! MUST BE SET TO RUN IN THE DIRECTORY WITH TEMPORARY SUBTITLES FILE (usually A_WorkingDir)
		RunWait, % ComSpec " /c """ encodeCMD """", %A_WorkingDir%, Hide
		if (ErrorLevel)
			throw ErrorLevel
	}

	prepareEncodingParameters(mode, sourceVideoFile, markA, markB) {
		if (FileExist(this.c_ffmpegLog)) {
			FileDelete, % this.c_ffmpegLog
		}
		; start forming FFMPEG parameters string according to requested mode
		ffmpegParams := this.c_ffmpegDefault
		
		if (mode >= 1) {
			subExtractCMD := this.getSubSource(sourceVideoFile, markA, markB)
			if (FileExist(this.c_tempSubFile))
				FileDelete, % this.c_tempSubFile
			FileAppend, ==SUBS==`n %subExtractCMD% `n, % this.c_ffmpegLog
			RunWait, % ComSpec " /c """ subExtractCMD """", %A_WorkingDir%, Hide
			FileGetSize, subFileSize, % this.c_tempSubFile
			; checking whether there actually are some subs available during our interval
			if (ErrorLevel or subFileSize = 0)
				ShowGUIMessage("No subtitles are available for this clip!`nWill encode without subs...",1)
			else {
				this.prepareSubtitles()
				ffmpegParams := this.c_ffmpegWsubs
			}
		}
		if (mode < 2)
			; no audio stream option
			ffmpegParams := " -an " ffmpegParams
		Else
			ffmpegParams := this.c_ffmpegSound ffmpegParams
		return ffmpegParams
	}

	getEncodingCommand(ffmpegParams, newVideoFullName, sourceVideoFile, markA, markB) {
		; all full paths passed by variables must be enclosed with "" 
		return % """" this.c_ffmpegExe """ -nostdin -ss " markA " -t " markB-markA " -i """ sourceVideoFile """ " this.c_forceFrate ffmpegParams " -t " markB-markA " """ newVideoFullName """ 2>> """ this.c_ffmpegLog """"
	}

	; look for separate subtitle files within input video folder
	; if none found, set the command to try extracting subtitles from the source video
	getSubSource(sourceVideoFile, markA, markB) {
		subFile := RegexReplace(sourceVideoFile, "\.[\w\d]+$", ".srt")
		assFile := RegexReplace(sourceVideoFile, "\.[\w\d]+$", ".ass")
		; checking whether .srt or .ass file with the same name as the video exists in the same directory
		if FileExist(subFile) 
			subExtractCMD := this.getSubsFromSubFile(markA, markB, SubFile)
		else if FileExist(assFile) 
			subExtractCMD := this.getSubsFromSubFile(markA, markB, AssFile)
		else 
			subExtractCMD := this.getSubsFromVideoFile(markA, markB, sourceVideoFile)
		return subExtractCMD
	}

	getSubsFromSubFile(markA, markB, subFile) {
		return % """" this.c_ffmpegExe """ -ss " markA " -t " markB-markA " -i """ subFile """ -t " markB-markA " """ this.c_tempSubFile """ 2>> """ this.c_ffmpegLog """"
	}

	getSubsFromVideoFile(markA, markB, videoFile) {
		return % """" this.c_ffmpegExe """ -ss " markA " -t " markB-markA this.c_forceFrate " -i """ videoFile """ -map 0:s:0 -t " markB-markA " """ this.c_tempSubFile """ 2>> """ this.c_ffmpegLog """"
	}

	prepareSubtitles() {
		; TODO add video size normalization
		FileRead, subContents, % this.c_tempSubFile
		; removing additional formatting tags from subs
		subContents := RegExReplace(subContents, "<.*?>")
		if (RegexMatch(subContents, "\Q[Script Info]\E")) {
			; hack .ass render resolution so the font size of the subs fits better
			subContents := RegexReplace(subContents, "PlayResX: \d+", "PlayResX: 800")
			subContents := RegexReplace(subContents, "\nPlayResY\: \d+", "")
			; TODO strip styles
		}
		subFile := FileOpen(this.c_tempSubFile, "w")
		subFile.Write(subContents)
		subFile.Close()
	}
}
