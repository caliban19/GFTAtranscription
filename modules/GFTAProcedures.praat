procedure TranscribeSegment(.target$, .pros$, .currentTrial, .whichSegment, .word$)
	# Zoom to the segmented interval in the editor window.
	editor 'transBasename$'
		Zoom: segmentXMin - 0.25, segmentXMax + 0.25
	endeditor

	.spacing = (segmentXMax - segmentXMin)/7
	start_time = segmentXMin + (.spacing * ((.whichSegment * 2) -1))
	end_time = segmentXMin + .spacing + (.spacing * ((.whichSegment * 2) -1))
	interval_mid = (start_time + ((end_time - start_time)/2))

	# Add boundaries and text to the Phonetic, Phonemic, transCheck tiers
	selectObject(transBasename$)
	Insert boundary... transcription_textgrid.prosodicPos 'start_time'
	Insert boundary... transcription_textgrid.prosodicPos 'end_time'
	Insert boundary... transcription_textgrid.phonemic 'start_time'
	Insert boundary... transcription_textgrid.phonemic 'end_time'

	# Add the transcriptions to the TextGrid.
	sound_int = Get interval at time... transcription_textgrid.phonemic 'interval_mid'
	Set interval text... transcription_textgrid.prosodicPos 'sound_int' '.pros$'
	Set interval text... transcription_textgrid.phonemic 'sound_int' '.target$'

	# Prompt the user to rate production.
	beginPause ("Rate the production of consonant #'.whichSegment'.")
		comment ("Next sound to transcribe: '.target$' at '.pros$' in '.word$'")
		comment ("Choose a phonemic transcription.")
		choice ("Rating", 1)
		option ("Correct")
		option ("Incorrect")
		option ("Untranscribeable")
	endPause ("Ruin everything", "Rate Production", 2, 1)
 
	if rating$ != "Untranscribeable"
		if rating$ = "Correct"
			.segmentScore = 1
		else
			.segmentScore = 0
		endif
		# Update the GFTA score.
		selectObject(transLogBasename$)

		.score = Get value: 1, transLogScore$
		.score = .score + .segmentScore
		Set numeric value: 1, transLogScore$, .score

		selectObject(transBasename$)
		Insert point... transcription_textgrid.score 'interval_mid' '.segmentScore'
	else
		# Update number of GFTA transcribeable segments.
		selectObject(transLogBasename$)

		.numTrabscribeable = Get value: 1, transLogTranscribeableTokens$
		.numTrabscribeable = .numTrabscribeable - 1
		Set numeric value: 1, transLogTranscribeableTokens$, .numTrabscribeable

		selectObject(transBasename$)
		Insert point... transcription_textgrid.score 'interval_mid' Not Transcribeable
	endif

	# Notes on the transcription of the word
	beginPause ("Notes")	
		comment ("Any notes on the transcription of this segment?")
		sentence ("trans_notes", "")
	endPause ("Ruin everything", "Finish transcribing this segment", 2, 1)

	if trans_notes$ != ""
		#middle_of_word_time = ('current_word_end' + 'current_word_start') / 2
		Insert point... transcription_textgrid.notes 'interval_mid' 'trans_notes$'
	endif

	selectObject(transBasename$)
	Save as text file: transcription_textgrid.filepath$

	selectObject(transLogBasename$)
	Save as tab-separated file: transcription_log.filepath$
endproc

procedure transcribe_notes(.trial_number, .word$, .target1$, .target2$)
	beginPause("Transcription Notes")
		@trial_header(.trial_number, .word$, .target1$, .target2$, 0)

		comment("You may enter any notes about this transcription below: ")
		text("transcriber_notes", "")

		comment("Should an audio and textgrid snippet be extracted for this trial?")
		boolean("Extract snippet", 0)
		
	button = endPause("Quit (without saving this trial)", "Transcribe it!", 2, 1)

	if button == 1
		.result_node$ = node_quit$
	else
		.notes$ = transcriber_notes$
		.no_notes = length(.notes$) == 0
		.snippet = extract_snippet
		.result_node$ = node_next$
	endif
endproc

### Procedures for checking/correcting GFTATranscription textgrids
procedure CheckGFTASegment(.target$, .whichPoint, .whichSegment, .word$, .pros$)
	if session_parameters.activity$ == "Correct a Transcribed TextGrid"
		.logRow = 1
	elsif session_parameters.activity$ == "Check a Transcribed TextGrid"
		.logRow = 2
	endif

	selectObject(transLogBasename$)
	.score = Get value: .logRow, transLogScore$
	.numTrabscribeable = Get value: .logRow, transLogTranscribeableTokens$

	selectObject(transBasename$)
	.originalSegScore$ = Get label of point: 3, .whichPoint

	beginPause("Target'.whichSegment' Transcription for '.word$'")
		comment("Is /'.target$'/ scored correctly?")
	button = endPause("Yes", "NO", "Quit", 1)

	if button == 1
		#copies over score if this is the checking script and the transcription was correct
		if .originalSegScore$ == "Not transcribeable" & .logRow == 2
			.originalSegScore = -1
		elsif .originalSegScore$ == "1" & .logRow == 2
			.originalSegScore = 1
		else
			.originalSegScore = 0
		endif
	elsif button == 2
		selectObject(transBasename$)
		.originalPointTime = Get time of point: 3, .whichPoint
		Remove point: 3, .whichPoint

		#Necessary score correction to log file if only a single trial is being corrected
		if .logRow == 1
			if .originalSegScore$ == "1"
				.score = .score - 1
			elsif .originalSegScore$ == "Not Transcribeable"
				.numTrabscribeable = .numTrabscribeable + 1
			endif
		endif

		# [RETRANSCRIBE Target]
		@retranscribeGFTASegment(.whichSegment, .originalPointTime, .target$, .word$, .pros$)
		.originalSegScore = retranscribeGFTASegment.segmentScore
	elsif button == 3
		goto abort
	endif

	selectObject(transLogBasename$)
	if .originalSegScore == 1
		.score = .score + 1
	elsif .originalSegScore == -1
		.numTrabscribeable = .numTrabscribeable - 1
	endif

	Set numeric value: .logRow, transLogScore$, .score
	Set numeric value: .logRow, transLogTranscribeableTokens$, .numTrabscribeable
endproc

procedure retranscribeGFTASegment(.whichSegment, .originalPointTime, .target$, .word$, .pros$)
	# Prompt the user to rate production.
	beginPause ("Rate the production of consonant #'.whichSegment'.")
		comment ("Next sound to transcribe: '.target$' at '.pros$' in '.word$'")
		comment ("Choose a phonemic transcription.")
		choice ("Rating", 1)
		option ("Correct")
		option ("Incorrect")
		option ("Untranscribeable")
	endPause ("Ruin everything", "Rate Production", 2, 1)
 
	if rating$ != "Untranscribeable"
		if rating$ = "Correct"
			.segmentScore = 1
		else
			.segmentScore = 0
		endif

		selectObject(transBasename$)
		Insert point... transcription_textgrid.score '.originalPointTime' '.segmentScore'
	else
		.segmentScore = -1
		selectObject(transBasename$)
		Insert point... transcription_textgrid.score '.originalPointTime' Not Transcribeable
	endif
endproc

#######################################################################
# PROCEDURE definitions start here

## This function is used to insert a row at the top of a table and write out 
## the name and value of a string variable in that row. It's used for testing 
## to show a "stack" of variable names and their values.
procedure writeLine .variable$
	# Store the value of the passed variable
	.value$ = '.variable$'
	
	# If other objects are selected in Praat, store their names
	.numberOfObjects = numberOfSelected ()	
	if .numberOfObjects > 0
		for i from 1 to .numberOfObjects
			.selection'i'$ = selected$ (i)
		endfor
	endif
	
	# Update the table with passed variable and its value
	select Table testing
	Set string value... 1 variable '.variable$'
	Set string value... 1 value '.value$'
	Insert row... 1
	
	# Restore Praat object selection
	if .numberOfObjects > 0
		select '.selection1$'
		if .numberOfObjects > 1		
			for i from 2 to .numberOfObjects
				.name$ = .selection'i'$
       				plus '.name$'
			endfor
		endif
	endif	
endproc

#### PROCEDURE to count GFTA wordlist structures for each of the three structure types.
procedure count_GFTA_wordlist_structures(.wordList_table$)
	# Get the number of trials in the Word List table.
	selectObject(.wordList_table$)
	.nTrials = Get number of rows
endproc