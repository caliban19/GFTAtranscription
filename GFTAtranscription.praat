#######################################################################
# Controls whether the @log_[...] procedures write to the InfoLines.
# debug_mode = 1
debug_mode = 0
continueTranscription = 1

include check_version.praat
include GFTAProcedures.praat
include ../L2T-utilities/L2T-Utilities.praat
include ../L2T-Audio/L2T-Audio.praat
include ../L2T-StartupForm/L2T-StartupForm.praat
include ../L2T-WordList/L2T-WordList.praat
include ../L2T-SegmentationTextGrid/L2T-SegmentationTextGrid.praat
include ../L2T-Transcription/L2T-Transcription.praat

# Set the session parameters.
defaultExpTask = 3
defaultTestwave = 1
defaultActivity = 3
@session_parameters: defaultExpTask, defaultTestwave, defaultActivity

# Load the audio file
@audio

# Load the WordList.
@wordlist

# Load the checked segmented TextGrid.
@segmentation_textgrid

# Set the transcription-specific parameters.
@transcription_parameters

# Numeric and string constants for the Word List Table.
wordListBasename$ = wordlist.praat_obj$
wordListWorldBet$ = wordlist_columns.worldBet$
wordListTargetC1$ = wordlist_columns.targetC1$
wordListTargetC2$ = wordlist_columns.targetC2$
wordListTargetC3$ = wordlist_columns.targetC3$
wordListprosPos1$ = wordlist_columns.prosPos1$
wordListprosPos2$ = wordlist_columns.prosPos2$
wordListprosPos3$ = wordlist_columns.prosPos3$

# Column numbers from the segmented textgrid
segTextGridTrial = segmentation_textgrid_tiers.trial
segTextGridContext = segmentation_textgrid_tiers.context

# Count the trials of structure type
@count_GFTA_wordlist_structures(wordListBasename$)
nTrials = count_GFTA_wordlist_structures.nTrials

@participant: audio.read_from$, session_parameters.participant_number$

# Check whether the log and textgrid exist already
@transcription_log("check", session_parameters.experimental_task$, participant.id$, session_parameters.initials$, transcription_parameters.logDirectory$, nTrials, 0, 0)
@transcription_textgrid("check", session_parameters.experimental_task$, participant.id$, session_parameters.initials$, transcription_parameters.textGridDirectory$))

# Load or initialize the transcription log/textgrid iff
# the log/textgrid both exist already or both need to be created.
if transcription_log.exists == transcription_textgrid.exists
	@transcription_log("load", session_parameters.experimental_task$, participant.id$, session_parameters.initials$, transcription_parameters.logDirectory$, nTrials, 0, 0)
	@transcription_textgrid("load", session_parameters.experimental_task$, participant.id$, session_parameters.initials$, transcription_parameters.textGridDirectory$)
# Otherwise exit with an error message
else
	log_part$ = "Log " + transcription_log.filename$
	grid_part$ = "TextGrid " + transcription_textgrid.filename$
	if transcription_log.exists
		msg$ = "Initialization error: " + log_part$ + "was found, but " + grid_part$ + " was not."
	else
		msg$ = "Initialization error: " + grid_part$ + "was found, but " + log_part$ + " was not."
	endif
	exitScript: msg$
endif

# Export values to global namespace
segmentBasename$ = segmentation_textgrid.praat_obj$
segmentTableBasename$ = segmentation_textgrid.tablePraat_obj$
audioBasename$ = audio.praat_obj$
transBasename$ = transcription_textgrid.praat_obj$
transLogBasename$ = transcription_log.praat_obj$

# These are column names
transLogTrials$ = transcription_log.trials$
transLogTrialsTranscribed$ = transcription_log.trials_transcribed$
transLogEndTime$ = transcription_log.end$
transLogScore$ = transcription_log.score$
transLogTranscribeableTokens$ = transcription_log.transcribeable$

###############################################################################
#                             Code for Transcription                                #
###############################################################################

# Open an Edit window with the segmentation textgrid, so that the transcriber can examine
# the larger segmentation context to recoup from infelicitous segmenting of false starts
# and the like. 
selectObject(segmentBasename$)
Edit

# Open a separate Editor window with the transcription textgrid object and audio file.
selectObject(transBasename$)
plusObject(audioBasename$)
Edit
# Set the Spectrogram settings, etc., here.

#Count remaining trials

@count_remaining_trials(transLogBasename$, 1, "NumberOfTrials", "NumberOfTrialsTranscribed")
n_trials = count_remaining_trials.n_trials
n_transcribed = count_remaining_trials.n_transcribed
n_remaining = count_remaining_trials.n_remaining

# If there are still trials to transcribe, ask the transcriber if she would like to transcribe them.
n_transcribed < n_trials
beginPause("Transcribe GFTA Trials")
	comment("There are 'n_remaining' trials to transcribe.")
	comment("Would you like to transcribe them?")
button = endPause("No", "Yes", 2, 1)

# If the user chooses no, skip the transcription loop and break out of this loop.
if button == 1
	continueTranscription = 0
else
	currentTrial = n_transcribed + 1
endif

selectObject(segmentTableBasename$)
Extract rows where column (text): "tier", "is equal to", "Trial"
Rename: "TierTimes"

# Loop through the trials of the current type
while (currentTrial <= n_trials & continueTranscription)
	# Look up trial number in segmentation table. Compute trial midpoint from table.
	select Table TierTimes
	.table_obj$ = selected$ ()
	@get_xbounds_from_table(.table_obj$, currentTrial)
	trialXMid = get_xbounds_from_table.xmid

	# Find bounds of the textgrid interval containing the trial midpoint
	@get_xbounds_in_textgrid_interval(segmentBasename$, segTextGridTrial, trialXMid)

	# Use the XMin and XMax of the current trial to extract that portion of the segmented 
	# TextGrid, preserving the times. The TextGrid Object that this operation creates will 
	# have the name:
	# ::ExperimentalTask::_::ExperimentalID::_::SegmentersInitials::segm_part
	selectObject(segmentBasename$)
	Extract part: get_xbounds_in_textgrid_interval.xmin, get_xbounds_in_textgrid_interval.xmax, "yes"

	# Convert the (extracted) TextGrid to a Table, which has the
	# same name as the TextGrid from which it was created.
	selectObject(segmentBasename$ + "_part")
	Down to Table: "no", 6, "yes", "no"
	selectObject(segmentBasename$ + "_part")
	Remove

	# Subset the 'segmentBasename$'_part Table to just the intervals on the Context Tier.
	selectObject(segmentTableBasename$ + "_part")
	Extract rows where column (text): "tier", "is equal to", "Context"
	selectObject(segmentTableBasename$ + "_part")
	Remove

	# Count the number of segmented intervals.
	selectObject(segmentTableBasename$ + "_part_Context")
	numResponses = Get number of rows
	# If there is more than one segmented interval, ...
	if numResponses > 1
		# Zoom to the entire trial in the segmentation TextGrid object and 
		# invite the transcriber to select the interval to transcribe.
		editor 'segmentBasename$'
			Zoom: get_xbounds_in_textgrid_interval.xmin, get_xbounds_in_textgrid_interval.xmax
		endeditor
		beginPause("Choose repetition number to transcribe")
			choice("Repetition number", numResponses)
				for repnum from 1 to 'numResponses'
					option("'repnum'")
				endfor
		button = endPause("Back", "Quit", "Choose repetition number", 3)
	else
		repetition_number = 1
	endif

	# Get the Context label of the chosen segmented interval of this trial and also then
	# mark it off in the transcription textgrid ready to transcribe or skip as a NonResponse.
	selectObject(segmentTableBasename$ + "_part_Context")
	contextLabel$ = Get value: repetition_number, "text"

	# Determine the XMin and XMax of the segmented interval.
	@get_xbounds_from_table(segmentTableBasename$ + "_part_Context", repetition_number)
	segmentXMid = get_xbounds_from_table.xmid

	@get_xbounds_in_textgrid_interval(segmentBasename$, segTextGridContext, segmentXMid)
	segmentXMin = get_xbounds_in_textgrid_interval.xmin
	segmentXMax = get_xbounds_in_textgrid_interval.xmax

	# Add interval boundaries on each tier.
	selectObject(transBasename$)
	Insert boundary: transcription_textgrid.prosodicPos, segmentXMin
	Insert boundary: transcription_textgrid.prosodicPos, segmentXMax
	Insert boundary: transcription_textgrid.phonemic, segmentXMin
	Insert boundary: transcription_textgrid.phonemic, segmentXMax

	# Determine the target word and target segments. 
	selectObject(wordListBasename$)
	targetWord$ = Get value: currentTrial, wordListWorldBet$
	targetC1$ = Get value: currentTrial, wordListTargetC1$
	targetC2$ = Get value: currentTrial, wordListTargetC2$
	targetC3$ = Get value: currentTrial, wordListTargetC3$
	prosPos1$ = Get value: currentTrial, wordListprosPos1$
	prosPos2$ = Get value: currentTrial, wordListprosPos2$
	prosPos3$ = Get value: currentTrial, wordListprosPos3$

	if targetC1$ != "" & targetC1$ != "?" 
		@TranscribeSegment(targetC1$, prosPos1$, currentTrial, 1, targetWord$)
	endif
	if targetC2$ != "" & targetC2$ != "?" 
		@TranscribeSegment(targetC2$, prosPos2$, currentTrial, 2, targetWord$)
	endif
	if targetC3$ != "" & targetC3$ != "?"
		@TranscribeSegment(targetC3$, prosPos3$, currentTrial, 3, targetWord$)
	endif

##### This results in a very ungraceful way to quit midstream.  Figure out a better way.

	# Ask the user if they want to keep transcribing or quit.
	beginPause ("")
		comment ("Would you like to keep transcribing?")
	clicked = endPause("Ruin everything", "Quit for now", "Continue transcribing", 3, 1)

	# If the transcriber doesn't want to continue...
	if clicked = 2
		# If the transcriber decided to quit, then set the 'trial'
		# variable so that the script breaks out of the while-loop.
		continueTranscription = 0
	else
		# Remove the segmented interval's Table from the Praat Object list.
		selectObject(segmentTableBasename$ + "_part_Context")
		Remove
	endif

	selectObject(transLogBasename$)
	@currentTime
	Set string value: 1, transLogEndTime$, currentTime.t$
	Set numeric value: 1, transLogTrialsTranscribed$, currentTrial
	Save as tab-separated file: transcription_log.filepath$

	#increment trial number
	currentTrial = currentTrial + 1
endwhile

select all
Remove