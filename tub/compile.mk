
#DFLAGS+=$(DIP25) $(DIP1000)
DFLAGS+=$(DPREVIEW)=inclusiveincontracts

#
# Change extend of the LIB
#
LIBEXT=${if $(SHARED),$(DLLEXT),$(STAEXT)}

#
# D compiler
#
$(DOBJ)/%.$(OBJEXT): $(DSRC)/%.d
	$(PRECMD)
	${call log.kvp, compile, $(MODE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $< $(DCOMPILE_ONLY) $(OUTPUT)$@


#
# Compile and link or split link
#
ifdef SPLIT_LINKER
#$(DOBJ)/%.$(OBJEXT): $(PREBUILD)

$(DOBJ)/lib%.$(OBJEXT): $(DOBJ)/.way
	$(PRECMD)
	${call log.kvp, compile$(MODE)}
	echo ${DFILES}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $(DFILES) $(DCOMPILE_ONLY)  $(OUTPUT)$@

$(DLIB)/lib%.$(DLLEXT): $(DOBJ)/lib%.$(OBJEXT)
	$(PRECMD)
	${call log.kvp, split-link$(MODE)}
	echo ${filter %.$(OBJEXT),$?}
	$(LD) ${LDFLAGS} ${filter %.$(OBJEXT),$?} $(LIBS) $(OBJS) -o$@
else
$(DLIB)/%.$(DLLEXT):
	$(PRECMD)
	${call log.kvp, link$(MODE), $(DMODULE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $(DFILES) ${LDFLAGS} $(LIBS) $(OBJS) $(DCOMPILE_ONLY)  $(OUTPUT)$@
endif

#
# proto targets for binaries
#

$(DBIN)/%:
	$(PRECMD)
	${call log.kvp, bin$(MOD), $*}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $(DFILES) ${LDFLAGS} $(LIBS) $(OBJS) $(OUTPUT)$@

#
# Proto targets for unittest
#
UNITTEST_FLAGS?=$(DUNITTEST) $(DDEBUG) $(DDEBUG_SYMBOLS)
UNITTEST_DOBJ=$(DOBJ)/unittest
UNITTEST_BIN?=$(DBIN)/unittest
UNITTEST_LOG?=$(DLOG)/unittest.log

proto-unittest-run: $(DLOG)/.way
proto-unittest-run: $(UNITTEST_BIN)
	$(PRECMD)
	$(SCRIPT_LOG) $(UNITTEST_BIN) $(UNITTEST_LOG)

$(UNITTEST_BIN): $$(DFILES)
	$(PRECMD)
	@echo deps $?
	$(DC) $(UNITTEST_FLAGS) $(DMAIN) $(DFLAGS) ${addprefix -I,$(DINC)} $(DFILES) $(LIBS) $(OUTPUT)$@


clean-unittest:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(UNITTEST_DOBJ)
	$(RM) $(UNITTEST_BIN)

clean: clean-unittest

help-unittest:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-unittest", "Will display this part"}
	${call log.help, "make clean-unittest", "Clean unittest files"}
	${call log.help, "make env-uintest", "List all unittest parameters"}
	${call log.close}

help: help-unittest

env-unittest:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, UNITTEST_DOBJ, $(UNITTEST_DOBJ)}
	${call log.env, UNITTEST_FLAGS, $(UNITTEST_FLAGS)}
	${call log.env, UNITTEST_BIN, $(UNITTEST_BIN)}

env: env-unittest

# Object Clear"
clean-obj:
	$(PRECMD)
	${call log.header, $@ :: obj}
	$(RM) $(DOBJALL)
	$(RM) $(DCIRALL)

clean: clean-obj

env-build:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, DINC, $(DINC)}

env: env-build
