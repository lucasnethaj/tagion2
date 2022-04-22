
TAGIONWAVE?=$(DBIN)/tagionwave
TAGIONBOOT?=$(DBIN)/tagionboot

DARTUTIL?=$(DBIN)/dartutil
HIBONUTIL?=$(DBIN)/hibonutil
TAGIONWALLET?=$(DBIN)/wallet

DARTBOOTRECORD = $(TESTBENCH)/bootrecord.hibon






WALLETFILES+=tagionwallet.hibon
WALLETFILES+=quiz.hibon
WALLETFILES+=device.hibon

# $1:name $2:testbench-path
define CREATE_WALLET
${eval
# $(TEST_DIR)/.wallet$1: PINCODE=$2
# $(TEST_DIR)/.wallet$1: AMOUNT=$4
# $(TEST_DIR)/.wallet$1: NAME=invoice_$3
# $(TEST_DIR)/.wallet$1: INVOICE_FILE=$$(TEST_DIR)/invoice_$3.hibon

# WALLETS+=$$(TEST_DIR)/wallet$1
# INVOICES+=$$(TEST_DIR)/invoice_$3.hibon
TESTBENCH_$1=$${abspath $2/$1}
BASEWALLET_$1=$$(FUND)/$1

BASEWALLETFILES_$1=$${addprefix $$(BASEWALLET_$1)/,$$(WALLETFILES)}
TESTWALLETFILES_$1=$${addprefix $$(TESTBENCH_$1)/,$$(WALLETFILES)}

STDINWALLET_$1=$$(BASEWALLET_$1)/wallet.stdin
INVOICES+=$$(TESTBENCH_$1)/invoice.hibon

.SECONDARY: $$(STDINWALLET_$1)
.SECONDARY: $$(BASEWALLETFILES_$1)
.SECONDARY: $$(TESTWALLETFILES_$1)
.SECONDARY: $$(TESTBENCH_$1)/tagionwallet.json

$1-wallet: | $$(TESTBENCH_$1)/.way
$1-wallet: $$(TESTBENCH_$1)/invoice.hibon

wallets: $1-wallet

$1-fundamental: $$(BASEWALLETFILES_$1)

$$(TESTBENCH_$1)/invoice.hibon: $$(TESTBENCH_$1)/tagionwallet.json $$(TESTWALLETFILES_$1)
	echo $$(TAGIONWALLET) $$< -x $$(PINCODE) -c $$(NAME):$$(AMOUNT) -i $$@

$$(TESTBENCH_$1)/tagionwallet.json: $$(TESTWALLETFILES_$1)
	echo $$(TAGIONWALLET) $$@ --path $$< -O

$$(TESTBENCH_$1)/%.hibon: $$(BASEWALLET_$1)/%.hibon
	cp $$< $$@

$$(BASEWALLET_$1)/%.hibon: $$(BASEWALLETFILES_$1)

$$(BASEWALLETFILES_$1): $$(STDINWALLET_$1)
	$$(PRECMD)
	cd $$(BASEWALLET_$1)
	cat $$< | $$(TAGIONWALLET)

env-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: env}
	$${call log.kvp, TESTBENCH_$1 $$(TESTBENCH_$1)}
	$${call log.kvp, BASEWALLET_$1 $$(BASEWALLET_$1)}
	$${call log.kvp, STDINWALLET_$1 $$(STDINWALLET_$1)}
	$${call log.env, TESTWALLETFILES_$1, $$(TESTWALLETFILES_$1)}
	$${call log.env, BASEWALLETFILES_$1, $$(BASEWALLETFILES_$1)}
	$${call log.close}

env-testbench: env-$1

help-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: help}
	$${call log.help, "make env-$1", "Displays env for $1-wallet"}
	$${call log.help, "make $1-wallet", "Creates $1-wallet"}
	$${call log.help, "make clean-$1", "cleans $1-wallet"}
	$${call log.help, "make remove-$1", "This will remove the fundation wallet."}
	$${call log.help, "", "Except the key file $$(STDINWALLET_$1)"}
	$${call log.help, "make $1-fundamental", "Generate the fundamental wallet which is stored in repositore"}
	$${call log.close}
.PHONY: help-$1

help-testbench: help-$1

clean-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: clean}
	$$(RMDIR) $$(TESTBENCH_$1)
	$${call log.close}

.PHONY: clean-$1

clean-testbench: clean-$1

remove-$1:
	$$(PRECMD)
	$${call log.header, $$@ :: remove}
	$$(RM) $$(STDINWALLET_$1)
	$${call log.close}

remove-testbench: remove-$1

.PHONY: remove-$1

}
endef

#include testbench_setup.mk

create-recorder: tools $(DARTBOOTRECORDER)
	$(PRECMD)$(TAGIONBOOT) $(INVOICES) -o $(DARTBOOTRECORDER)

create-invoices: tools $(INVOICES)

$(DARTBOOTRECORDER): $(INVOICES)
	$(PRECMD)$(TAGIONBOOT) $? -o $@

env-testbench:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, TAGIONWAVE, $(TAGIONWAVE)}
	${call log.kvp, TAGIONBOOT, $(TAGIONBOOT)}
	${call log.kvp, DARTUTIL, $(DARTUTIL)}
	${call log.kvp, TAGIONWALLET, $(TAGIONWALLET)}
	${call log.kvp, HIBONUTIL, $(HIBONUTIL)}
	${call log.kvp, DARTBOOTRECORD, $(DARTBOOTRECORD)}
	${call log.env, INVOICES, $(INVOICES)}
	${call log.close}

.PHONY: env-testbench

env: env-testbench

help-testbench:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make testbench", "Runs the testbench"}
	${call log.help, "make wallets", "Will create all testwallets"}
	${call log.help, "make clean-testbench", "Cleans all the wallets"}
	${call log.help, "make remove-testbench", "Cleans all the wallets"}
	${call log.close}

.PHONY: help-testbench

help: help-testbench

.PHONY: clean-testbench

clean: clean-testbench

.PHONY: remove-testbench

${foreach wallet,$(WALLETS),${call CREATE_WALLET,$(wallet),$(TESTBENCH)}}
