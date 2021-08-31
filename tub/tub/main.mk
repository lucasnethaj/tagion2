# Choosing root directory
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)

ifneq ($(shell test -e $(DIR_MAKEFILE)/env.mk && echo yes),yes)
DIR_TUB := $(DIR_MAKEFILE)/tub
endif

DIR_TUB_ROOT := ${realpath ${DIR_TUB}/../}

ifneq ($(shell test -e $(DIR_TUB_ROOT)/.tubroot && echo yes),yes)
DIR_TUB_ROOT := $(DIR_MAKEFILE)/tub
endif

# Inlclude local setup
-include $(DIR_TUB_ROOT)/local.mk

# Including according to anchor directory
include $(DIR_TUB)/utils.mk
include $(DIR_TUB)/log.mk
include $(DIR_TUB)/help.mk
include $(DIR_TUB)/env.mk

main: help
help: $(HELP)

install:
	@$(DIR_TUB)/install

update:
	@cd $(DIR_TUB); git checkout .
	@cd $(DIR_TUB); git pull origin --force

include $(DIR_TUB)/add.mk
include $(DIR_TUB)/revision.mk
include $(DIR_TUB)/compile.mk
include $(DIR_TUB)/clean.mk

.PHONY: help info
.SECONDARY: