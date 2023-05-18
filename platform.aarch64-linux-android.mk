# General android config

gendroid:
	@echo is Android $(findstring android,$(PLATFORM))

#
# Linux aarch64 Android
#

ANDROID_AARCH64=aarch64-linux-android
PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))

ANDROID_API?=21
ANDROID_ABI?=aarch64

HOST_OS:=${shell uname -s | tr '[:upper:]' '[:lower:]' }
HOST_ARCH:=${shell uname -m}
ANDROID_TOOLCHAIN:=$(ANDROID_NDK)/toolchains/llvm/prebuilt/${HOST_OS}-${HOST_ARCH}

MTRIPLE:=aarch64-linux
TRIPLET:=$(MTRIPLE)-android

export AR:=$(ANDROID_TOOLCHAIN)/bin/$(TRIPLET)-ar
export AS:=$(ANDROID_TOOLCHAIN)/bin/$(TRIPLET)-as
export CC:=$(ANDROID_TOOLCHAIN)/bin/$(TRIPLET)$(ANDROID_API)-clang
export CXX:=$(ANDROID_TOOLCHAIN)/bin/$(TRIPLET)$(ANDROID_API)-clang++
export LD:=$(ANDROID_TOOLCHAIN)/bin/$(TRIPLET)-ld
export RANLIB:=$(ANDROID_TOOLCHAIN)/bin/$(TRIPLET)-ranlib
export STRIP:=$(ANDROID_TOOLCHAIN)/bin/$(TRIPLET)-strip

## Still need to see if can somehow specify the ldc's lib-dirs from commandline
ANDROID_LDC_LIBS=$(ANDROID_LDC)

CROSS_ENABLED=1
CROSS_OS=android
CROSS_GO_ARCH=arm64
CROSS_ARCH=aarch64

SHARED?=1
DFLAGS+=$(DDEFAULTLIBSTATIC)
DFLAGS+=-i

ANDROID_ARCH=$(ANDROID_AARCH64)
DFLAGS+=-mtriple=$(PLATFORM)

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

env-android:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, ANDROID_NDK, $(ANDROID_NDK)}
	${call log.kvp, ANDROID_API, $(ANDROID_API)}
	${call log.kvp, ANDROID_ABI, $(ANDROID_ABI)}
	${call log.kvp, ANDROID_TOOLCHAIN, $(ANDROID_TOOLCHAIN)}
	${call log.kvp, LD, $(LD)}
	${call log.kvp, CC, $(CC)}
	${call log.kvp, CXX, $(CXX)}
	${call log.kvp, STRIP, $(STRIP)}
	${call log.kvp, AR, $(AR)}
	${call log.kvp, RANLIB, $(RANLIB)}
	${call log.kvp, AS, $(AS)}
	${call log.close}

env: env-android

help-android:
	$(PRECMD)
	${call log.header, $@ :: help}
	echo '     _________________________________________ '
	echo '    / It looks like youre trying to cross     \'
	echo '    | compile for android, did you know that  |'
	echo '    | you need androids snowflake linker in   |'
	echo '    | order to that. You can specify it by    |'
	echo '    | providing the path you android ndk with |'
	echo '    \ ANDROID_NDK=                            /'
	echo '     ----------------------------------------- '
	echo '     \                                         '
	echo '      \                                        '
	echo '         __                                    '
	echo '        /  \                                   '
	echo '        |  |                                   '
	echo '        @  @                                   '
	echo '        |  |                                   '
	echo '        || |/                                  '
	echo '        || ||                                  '
	echo '        |\_/|                                  '
	echo '        \___/                                  '
	${call log.help, "make env-android", "Will list the current setting"}
	${call log.help, "make help-android", "This will show how to change tagion platform change"}
	${call log.close}

help: help-android

.PHONY: env-android help-android

endif

