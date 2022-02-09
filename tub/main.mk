
.SUFFIXES:
.SECONDARY:
.ONESHELL:
.SECONDEXPANSION:

#MTRIPLE=$$(TRIPLE)


# Common variables
# Override PRECMD= to see output of all commands
PRECMD ?= @

main: help

#
# Defining absolute Root and Tub directories
#
export DSRC := $(realpath src)
export DTUB := $(realpath tub)
export DROOT := ${abspath ${DTUB}/../}

#
# Local config, ignored by git
#
-include $(DROOT)/local.*.mk
-include $(DROOT)/local.mk
include $(DTUB)/utilities/dir.mk
include $(DTUB)/utilities/log.mk

include $(DTUB)/tools/*.mk
include $(DTUB)/config/git.mk
include $(DTUB)/config/commands.mk



#
# Native platform
#
# This is the HOST target platform
#
HOST_PLATFORM=${call join-with,-,$(GETARCH) $(GETHOSTOS) $(GETOS)}
PLATFORM?=$(HOST_PLATFORM)

#
# Platform
#
include $(DTUB)/config/dirs.mk
-include $(DBUILD)/gen.dfiles.mk
-include $(DBUILD)/gen.ddeps.mk

-include $(DROOT)/platform.*.mk

#
# Secondary tub functionality
#
include $(DTUB)/ways.mk
include $(DTUB)/gitconfig.mk
include $(DTUB)/config/submodules.mk
include $(DTUB)/config/druntime.mk
include $(DTUB)/config/submake.mk
include $(DTUB)/config/host.mk
include $(DTUB)/config/cross.mk
include $(DTUB)/config/platform.mk
include $(DTUB)/config/auxiliary.mk

#
# Packages
#

include $(DTUB)/config/compiler.mk
include $(DTUB)/config/dstep.mk
include $(DTUB)/config/ddeps.mk

include $(DTUB)/compile.mk

#
# Include all unit make files
#
-include $(DSRC)/wrap-*/context.mk
-include $(DSRC)/lib-*/context.mk
-include $(DSRC)/bin-*/context.mk

#
# Root config
#
-include $(DROOT)/config.*.mk
-include $(DROOT)/config.mk


include $(DTUB)/config/prebuild.mk

#
# Enable cleaning
#
include $(DTUB)/clean.mk

#
# Help
#
include $(DTUB)/help.mk
