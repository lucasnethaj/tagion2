
#
# Targets for all binaries
#

#
# Core program
#
target-tagionwave: LIBS+=$(LIBOPENSSL)
target-tagionwave: LIBS+=$(LIBSECP256K1)
target-tagionwave: LIBS+=$(LIBP2PGOWRAPPER)
target-tagionwave: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wave/*"}
target-tagionwave: $(DBIN)/tagionwave
.PHONY: target-tagionwave

clean-tagionwave:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/tagionwave

clean: clean-tagionwave

BIN_TARGETS+=target-tagionwave
#
# HiBON utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-hibonutil: LIBS+=$(LIBOPENSSL)
target-hibonutil: LIBS+=$(LIBSECP256K1)
target-hibonutil: LIBS+=$(LIBP2PGOWRAPPER)

target-hibonutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-hibonutil/*"}
target-hibonutil: $(DBIN)/hibonutil

clean-hibonutil:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/hibonutil

clean: clean-hibonutil

BIN_TARGETS+=target-hibonutil

#
# DART utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-dartutil: LIBS+=$(LIBOPENSSL)
target-dartutil: LIBS+=$(LIBSECP256K1)
target-dartutil: LIBS+=$(LIBP2PGOWRAPPER)
target-dartutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-dartutil/*"}
target-dartutil: $(DBIN)/dartutil

clean-dartutil:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/dartutil

clean: clean-dartutil

BIN_TARGETS+=target-dartutil

#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-wasmutil: LIBS+=$(LIBOPENSSL)
target-wasmutil: LIBS+=$(LIBSECP256K1)
target-wasmutil: LIBS+=$(LIBP2PGOWRAPPER)
target-wasmutil: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wasmutil/*"}
target-wasmutil: $(DBIN)/wasmutil

clean-wasmutil:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/wasmutil

clean: clean-wasmutil

BIN_TARGETS+=target-wasmutil


#
# WASM utility
#
# FIXME(CBR) should be remove when ddeps works correctly
target-wallet: LIBS+=$(LIBOPENSSL)
target-wallet: LIBS+=$(LIBSECP256K1)
target-wallet: LIBS+=$(LIBP2PGOWRAPPER)
target-wallet: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-wallet/*"}
target-wallet: $(DBIN)/wallet

clean-wallet:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/wallet

clean: clean-wallet


BIN_TARGETS+=target-wallet


#
# Logservicetest utility
#
# FIXME(IB) should be removed when ddeps works correctly
target-tagionlogservicetest: LIBS+=$(LIBOPENSSL)
target-tagionlogservicetest: LIBS+=$(LIBSECP256K1)
target-tagionlogservicetest: LIBS+=$(LIBP2PGOWRAPPER)

target-tagionlogservicetest: DFILES+=${shell find $(DSRC) -name "*.d" -a -path "*/src/bin-logservicetest/*"}
target-tagionlogservicetest: $(DBIN)/tagionlogservicetest

clean-tagionlogservicetest:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(DBIN)/tagionlogservicetest

clean: clean-tagionlogservicetest

BIN_TARGETS+=target-tagionlogservicetest
