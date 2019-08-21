; Ffmpeg  handler CLASS ----------------------------------------------

Class Ffmpeg {
	; wrappers for parameters corresponding to the encoder (ffmpeg) options
; ENCODER PARAMETERS ----------------------------------------------------------
; EDITED vvvvvvvvvvv - framerate 24000/1001 fps
; you can set this option to "" to use file's framerate but there will be unpredictable
; glitches with some codec/container combinations, or if input video has variable framerate
	ntscRate {
		get {
			return " -r ntsc-film "
		}
	}
; no subtitle tracks, 8-bit color, rescale to make pixels square, width 800px or native if it's lower, height dividable by 2,
; worst recommended h264 quality (28, lower is better, down to 18), encode with libx264
	defaultParams {
		get {
			return " -sn -pix_fmt yuv420p -vf ""scale=iw*sar:ih, scale='min(800,iw)':-2"" -crf 28 -c:v libx264 "
		}
	}
; everything else should be obvious, while PrimaryColour format is &H<2-symbol hexcode for transparency level><BBGGRR color hex code>
; any ASS style fields https://pastebin.com/80yDaaRF should be usable under 'force_style' parameter
	withSubs {
		get {
			return " -sn -pix_fmt yuv420p -vf ""[in]scale=iw*sar:ih, scale='min(800,iw)':-2, subtitles=temp_subs.ass:force_style='FontName=Open Sans Semibold,FontSize=45,PrimaryColour=&H00FFFFFF,Bold=1'"" -crf 28 -c:v libx264 "
		}
	}
; " -c:a copy " should be usable for 95% cases probably, like all HorribleSubs ongoing releases
; " -c:a aac -b:a 128k -ac 2 " will recode audio to AAC 128kbit/s stereo
; (in case of 5.1 stuff or awkward codecs)
	withSound {
		get {
			return " -c:a aac -b:a 128k -ac 2 "
		}
	}

; FILE LOCATIONS
	exeFile {
		get {
			return WORK_FOLDER "\ffmpeg.exe"
		}
	}
	logFile {
		get {
			return WORK_FOLDER "\ffmpeg_gifer.log"
		}
	}
	tempSubFile {
		get {
			return WORK_FOLDER "\temp_subs.ass"
		}
	}
}

; EncoderInterface CLASS ----------------------------------------------------------

Class EncoderInterface {
	; NO GLOBALS BELOW THIS LINE ----------------------------------------------
	
	encode(mode, newVideoFullName, sourceVideoFile, markA, markB) {
		ffmpegParams := this.prepareEncodingParameters(mode, sourceVideoFile, markA, markB)
		encodeCMD := this.getEncodingCommand(ffmpegParams, newVideoFullName, sourceVideoFile, markA, markB)
		FileAppend, ==Encode start (debug)==`n %encodeCMD% `n, % Ffmpeg.logFile

		; whole command string must be enclosed with double quotes as well
		; WARNING! MUST BE SET TO RUN IN THE DIRECTORY WITH TEMPORARY SUBTITLES FILE (usually A_WorkingDir)
		RunWait, % ComSpec " /c """ encodeCMD """", %A_WorkingDir%, Hide
		if (ErrorLevel)
			throw ErrorLevel
	}

	prepareEncodingParameters(mode, sourceVideoFile, markA, markB) {
		if (FileExist(Ffmpeg.logFile)) {
			FileDelete, % Ffmpeg.logFile
		}
		; start forming FFMPEG parameters string according to requested mode
		ffmpegParams := Ffmpeg.defaultParams
		
		if (mode >= 1) {
			subExtractCMD := this.getSubSource(sourceVideoFile, markA, markB)
			if (FileExist(Ffmpeg.tempSubFile))
				FileDelete, % Ffmpeg.tempSubFile
			FileAppend, ==Sub extraction start (debug)==`n %subExtractCMD% `n, % Ffmpeg.logFile
			RunWait, % ComSpec " /c """ subExtractCMD """", %A_WorkingDir%, Hide
			FileGetSize, subFileSize, % Ffmpeg.tempSubFile
			; checking whether there actually are some subs available during our interval
			if (ErrorLevel or subFileSize = 0)
				ShowGUIMessage("No subtitles are available for this clip!`nWill encode without subs...",1)
			else {
				this.prepareSubtitles()
				ffmpegParams := Ffmpeg.withSubs
			}
		}
		if (mode < 2)
			; no audio stream option
			ffmpegParams := " -an " ffmpegParams
		Else
			ffmpegParams := Ffmpeg.withSound ffmpegParams
		return ffmpegParams
	}

	getEncodingCommand(ffmpegParams, newVideoFullName, sourceVideoFile, markA, markB) {
		; all full paths passed by variables must be enclosed with "" 
		return % """" Ffmpeg.exeFile """ -nostdin -ss " markA " -t " markB-markA " -i """ sourceVideoFile """ " Ffmpeg.ntscRate ffmpegParams " -t " markB-markA " """ newVideoFullName """ 2>> """ Ffmpeg.logFile """"
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
		return % """" Ffmpeg.exeFile """ -ss " markA " -t " markB-markA " -i """ subFile """ -t " markB-markA " """ Ffmpeg.tempSubFile """ 2>> """ Ffmpeg.logFile """"
	}

	getSubsFromVideoFile(markA, markB, videoFile) {
		return % """" Ffmpeg.exeFile """ -ss " markA " -t " markB-markA Ffmpeg.ntscRate " -i """ videoFile """ -map 0:s:0 -t " markB-markA " """ Ffmpeg.tempSubFile """ 2>> """ Ffmpeg.logFile """"
	}

	prepareSubtitles() {
		FileRead, subContents, % Ffmpeg.tempSubFile
		; removing additional formatting tags from subs
		subContents := RegExReplace(subContents, "<.*?>")
		if (RegexMatch(subContents, "\Q[Script Info]\E")) {
			; hack .ass render resolution so the font size of the subs fits better
			subContents := RegexReplace(subContents, "PlayResX: \d+", "PlayResX: 800")
			subContents := RegexReplace(subContents, "\nPlayResY\: \d+", "")
			; TODO strip styles
		}
		subFile := FileOpen(Ffmpeg.tempSubFile, "w")
		subFile.Write(subContents)
		subFile.Close()
	}
}
