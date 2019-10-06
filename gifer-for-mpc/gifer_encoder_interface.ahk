; Ffmpeg  handler CLASS ----------------------------------------------

Class Ffmpeg {
; ENCODER PARAMETERS ----------------------------------------------------------

; framerate 24000/1001 fps
; you can set this option to "" to use file's framerate but there will be unpredictable
; glitches with some codec/container combinations, or if input video has variable framerate
	ntscRate {
		get {
			return " -r ntsc-film "
		} }
; no subtitle tracks, 8-bit color, rescale to make pixels square, width {CLIP_WIDTH}px or native if it's lower, height dividable by 2,
; {CLIP_QUALITY} h264 quality (28, lower is better, down to 18), encode with libx264
	paramsPattern {
		get { 
			return " -sn -pix_fmt yuv420p -vf ""scale=iw*sar:ih, scale='min({1},iw)':-2{2}"" -crf {3} -c:v libx264 "
		} }
	defaultParams {
		get {
			settingsDefault := [CLIP_WIDTH, "", CLIP_QUALITY]
			return format(Ffmpeg.paramsPattern, settingsDefault*)
		} }
; everything else should be obvious, while PrimaryColour format is &H<2-symbol hexcode for transparency level><BBGGRR color hex code>
; any ASS style fields https://pastebin.com/80yDaaRF should be usable under 'force_style' parameter
	subsPattern {
		get {
			return format(", subtitles={1}:force_style='FontName=Open Sans Semibold,FontSize=45,PrimaryColour=&H00FFFFFF,Bold=1'", TEMP_SUB_FILE)
		} }
	withSubs {
		get {
			settingsSubs := [CLIP_WIDTH, FFmpeg.subsPattern, CLIP_QUALITY]
			return format(Ffmpeg.paramsPattern, settingsSubs*)
		} }
; " -c:a copy " should be usable for 95% cases probably, like all HorribleSubs ongoing releases
; " -c:a aac -b:a 128k -ac 2 " will recode audio to AAC 128kbit/s stereo
; (in case of 5.1 stuff or awkward codecs)
	withSound {
		get {
			return " -c:a aac -b:a 128k -ac 2 "
		} }

; FILE LOCATIONS
	exeFile {
		get {
			return WORK_FOLDER "\ffmpeg.exe"
		} }
	logFile {
		get {
			return WORK_FOLDER "\ffmpeg_gifer.log"
		} }
	tempSubFile {
		get {
			return WORK_FOLDER "\" TEMP_SUB_FILE
		} }

	getEncodingCommand(ffmpegParams, clip) {
		cmdParams := [Ffmpeg.exeFile, clip.startPos, clip.duration, clip.sourceFile, Ffmpeg.ntscRate, ffmpegParams, clip.duration, clip.clipFile, Ffmpeg.logFile]
		return format("""{1}"" -nostdin -ss {2} -t {3} -i ""{4}"" {5} {6} -t {7} ""{8}"" 2>> ""{9}""", cmdParams*)
	}

	getSubsFromSubFile(startPos, duration, subFile) {
		cmdParams := [Ffmpeg.exeFile, startPos, duration, subFile, duration, Ffmpeg.tempSubFile, Ffmpeg.logFile]
		return format("""{1}"" -ss {2} -t {3} -i ""{4}"" -t {5} ""{6}"" 2>> ""{7}""", cmdParams*)
	}

	getSubsFromVideoFile(startPos, duration, videoFile) {
		cmdParams := [Ffmpeg.exeFile, startPos, duration, videoFile, duration, Ffmpeg.ntscRate, Ffmpeg.tempSubFile, Ffmpeg.logFile]
		return format("""{1}"" -ss {2} -t {3} -i ""{4}"" -map 0:s:0 -t {5} {6} ""{7}"" 2>> ""{8}""", cmdParams*)
	}
}

; NO GLOBALS BELOW THIS LINE --------------------------------------------------
; EncoderInterface CLASS ----------------------------------------------------------

Class EncoderInterface {
	encode(clip) {
		ffmpegParams := this.prepareEncodingParameters(clip)
		encodeCMD := Ffmpeg.getEncodingCommand(ffmpegParams, clip)
		
		FileAppend, ==Encode start (debug)==`n %encodeCMD% `n, % Ffmpeg.logFile
		; whole command string must be enclosed with double quotes as well
		; WARNING! MUST BE SET TO RUN IN THE DIRECTORY WITH TEMPORARY SUBTITLES FILE (usually A_WorkingDir)
		RunWait, % ComSpec " /c """ encodeCMD """", %A_WorkingDir%, Hide
		if (ErrorLevel)
			throw ErrorLevel
	}

	prepareEncodingParameters(clip) {
		if (FileExist(Ffmpeg.logFile)) {
			FileDelete, % Ffmpeg.logFile
		}
		; start forming FFMPEG parameters string according to requested mode
		ffmpegParams := Ffmpeg.defaultParams
		
		if (clip.mode >= 1) {
			subExtractCMD := this.getSubSource(clip)
			if (this.extractAndCheckSubs(subExtractCMD)) {
				this.prepareSubtitles()
				ffmpegParams := Ffmpeg.withSubs
			} else {
				ShowGUIMessage("No subtitles are available for this clip!`nWill encode without subs...",1)
			}
		}
		
		if (clip.mode < 2)
			; no audio stream option
			ffmpegParams := " -an " ffmpegParams
		Else
			ffmpegParams := Ffmpeg.withSound ffmpegParams
		return ffmpegParams
	}

	; look for separate subtitle files within input video folder
	; if none found, set the command to try extracting subtitles from the source video
	getSubSource(clip) {
		subFile := RegexReplace(clip.sourceFile, "\.[\w\d]+$", ".srt")
		assFile := RegexReplace(clip.sourceFile, "\.[\w\d]+$", ".ass")
		if FileExist(subFile) 
			subExtractCMD := Ffmpeg.getSubsFromSubFile(clip.startPos, clip.duration, SubFile)
		else if FileExist(assFile) 
			subExtractCMD := Ffmpeg.getSubsFromSubFile(clip.startPos, clip.duration, AssFile)
		else 
			subExtractCMD := FFmpeg.getSubsFromVideoFile(clip.startPos, clip.duration, clip.sourceFile)
		return subExtractCMD
	}

	extractAndCheckSubs(subExtractCMD) {
		if (FileExist(Ffmpeg.tempSubFile))
			FileDelete, % Ffmpeg.tempSubFile
		FileAppend, ==Sub extraction start (debug)==`n %subExtractCMD% `n, % Ffmpeg.logFile
		RunWait, % ComSpec " /c """ subExtractCMD """", %A_WorkingDir%, Hide
		
		FileGetSize, subFileSize, % Ffmpeg.tempSubFile
		; checking whether there actually are some subs available during our interval
		if (ErrorLevel or subFileSize = 0)
			return False
		else 
			return True
	}
	
	prepareSubtitles() {
		FileRead, subContents, % Ffmpeg.tempSubFile
		; removing additional formatting tags from subs
		subContents := RegExReplace(subContents, "<.*?>")
		if (RegexMatch(subContents, "\Q[Script Info]\E")) {
			; hack .ass render resolution so the font size of the subs fits better
			subContents := RegexReplace(subContents, "PlayResX: \d+", "PlayResX: 800")
			subContents := RegexReplace(subContents, "PlayResY:.*?\r\n", "")
			subContents := RegexReplace(subContents, ";.*?\r\n", "")
			; TODO unify styles
		}
		subFile := FileOpen(Ffmpeg.tempSubFile, "w")
		subFile.Write(subContents)
		subFile.Close()
	}
}
