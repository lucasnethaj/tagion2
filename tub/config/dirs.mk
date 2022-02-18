export BUILD := ${abspath ${DROOT}/build/}
export LOG := ${abspath ${DROOT}/logs/}

export DBUILD := ${abspath $(BUILD)/$(PLATFORM)}
export DLOG := ${abspath $(LOG)/$(PLATFORM)}

# New simplified flow directories
export DBIN := $(DBUILD)/bin
export DTMP := $(DBUILD)/tmp
export DOBJ := $(DBUILD)/obj
export DLIB := $(DBUILD)/lib

env-dirs:
	$(PRECMD)
	$(call log.header, $@ :: dirs)
	$(call log.kvp, BUILD, $(BUILD))
	$(call log.kvp, DBUILD, $(DBUILD))
	$(call log.kvp, DBIN, $(DBIN))
	$(call log.kvp, DOBJ, $(DOBJ))
	$(call log.kvp, DTMP, $(DTMP))
	$(call log.kvp, DLIB, $(DLIB))
	$(call log.kvp, DLOG, $(DLOG))
	$(call log.kvp, DSRC, $(DSRC))
	$(call log.kvp, DTUB, $(DTUB))
	$(call log.kvp, DROOT, $(DROOT))
	$(call log.close)

env: env-dirs

clean-logs:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(DLOG)

help-logs:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make clean-logs", "Clean all generated .log files"}
	${call log.close}

help: help-logs

clean: clean-logs
