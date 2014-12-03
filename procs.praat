# Very generic procedures

procedure selectSound(.x$)
	selectObject("Sound " + .x$)
endproc

procedure selectTextGrid(.x$)
	selectObject("TextGrid " + .x$)
endproc

procedure selectTable(.x$)
	selectObject("Table " + .x$)
endproc

procedure currentTime()
	.t$ = replace$(date$(), " ", "_", 0)
endproc