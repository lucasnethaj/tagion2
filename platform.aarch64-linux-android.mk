
ANDROID_AARCH64=aarch64-linux-android
PLATFORMS+=$(ANDROID_AARCH64)

ifeq ($(PLATFORM),$(ANDROID_AARCH64))

CROSS_OS=android
CROSS_GO_ARCH=arm64
CROSS_ARCH=aarch64

SHARED?=1
SPLIT_LINKER?=1

ANDROID_ARCH=$(ANDROID_AARCH64)

TRIPLE = $(ANDROID_ARCH)

DINC+=${shell find $(DSRC) -maxdepth 1 -type d -path "*src/lib-*" }

ifdef BETTERC
LIBNAME?=libwallet-betterc-$(CROSS_ARCH)
LIBRARY=$(DLIB)/$(LIBNAME).$(LIBEXT)
LIBOBJECT=$(DOBJ)/$(LIBNAME).$(OBJEXT)
MODE:=-lib-betterc

#
# Files to be include
#
DFILES?=${shell find $(DSRC) -type f -name "*.d" -a -not -name "~*" -path "*src/lib-betterc*" -not -path "*/tests/*"}


#
# Switch in the betterC flags if has been defined
#
ANDROID_DFLAGS+=$(DBETTERC)

#
# Swicth off the phobos and druntime
#

ifdef SHARED
ANDROID_LDFLAGS+=-shared
endif

ANDROID_LDFLAGS+=-m aarch64linux

else
${error The none betterC version is not implemented yet. Set BETTERC=1}
#XFILES?=${shell find $(DSRC) -type f -name "*.d" -path "*src/lib-betterc*" -not -path "*/tests/*"}
endif

# CROSS_LIB=$(CROSS_SYSROOT)/usr/lib/$(ANDROID_ARCH)/$(ANDROID_NDK)
# OBJS+=$(CROSS_LIB)/crtbegin_so.o

ANDROID_LDFLAGS+=--fix-cortex-a53-843419

#
# Link all into one library
#
#ANDROID_LDFLAGS+=-Wl,--whole-archive
ANDROID_DFLAGS+=--defaultlib=libdruntime-ldc.a,libphobos2-ldc.a

ANDROID_DFLAGS+=-L/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/lib/
ANDROID_DFLAGS+=-L/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/lib/
ANDROID_DFLAGS+=-I/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/ldc-src/runtime/phobos/
ANDROID_DFLAGS+=-I/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/ldc-src/runtime/druntime/src/
ANDROID_DFLAGS+=--conf=
ANDROID_DFLAGS+=--flto=thin
ANDROID_DFLAGS+=--Oz

#ANDROID_DFLAGS+=--static

target-android: LD=$(ANDROID_LD)
target-android: CC=$(ANDROID_CC)
target-android: CPP=$(ANDROID_CPP)
#target-android: LDFLAGS=$(ANDROID_LDFLAGS)
target-android: DFLAGS+=$(ANDROID_DFLAGS)
target-android: LIBS+=/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/lib/libdruntime-ldc.a
target-android: LIBS+=/home/carsten/work/ldc-runtime/ldc-build-runtime.tmp/lib/libphobos2-ldc.a


#target-android: DFLAGS+=--static
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/array/equality.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/hash.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/traits.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/convert.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/entrypoint.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/array/appending.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/array/comparison.d

# #target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/std/algorithm/comparison.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/std/typecons.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/std/format.d

# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/array/concatenation.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/array/casting.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/array/construction.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/array/capacity.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/vararg.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/stdc/stdarg.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/std/meta.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/std/traits.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/std/functional.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/std/functional.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/object.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/dassert.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/destruction.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/moving.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/postblit.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/core/internal/switch_.d
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/ldc/internal/vararg.di
# target-android: DFILES+=/usr/lib/ldc/x86_64-linux-gnu/include/d/std/range/primitives.d
# target-android: DFLAGS+=--singleobj
target-android: LDFLAGS+=$(ANDROID_LDFLAGS)

target-android: LDFLAGS+=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtbegin_so.o
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/aarch64
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/aarch64-linux-android/4.9.x
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android
target-android: LDFLAGS+=-L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib
target-android: LDFLAGS+=-soname $(LIBRARY)
target-android: LDFLAGS+=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a
target-android: LDFLAGS+=-l:libunwind.a
target-android: LDFLAGS+=-ldl
target-android: LDFLAGS+=-lc
target-android: LDFLAGS+=-lm
# target-android: LDFLAGS+=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a
# target-android: LDFLAGS+=-l:libunwind.a
# target-android: LDFLAGS+=-ldl
target-android: LDFLAGS+=/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtend_so.o

#target-android: LIBS+=$(LIBSECP256K1)


target-android: | secp256k1

# To make sure that the all has been defined correctly
# The library must be expanded on the second pass
ifdef OPT_ONLY_OBJ
target-android: $$(LIBOBJECT)
else
target-android: $$(LIBRARY)
endif

platform: target-android

platform: show

show:
	@echo LIBEXT=$(LIBEXT)
	@echo SHARED=$(SHARED)
	@echo LIBRARY=$(LIBRARY)
	@echo DLIB=$(DLIB)
	@echo DOBJ=$(DOBJ)
	@echo DFILES=$(DFILES)
	@echo ANDROID_DFLAGS=$(ANDROID_DFLAGS)
	@echo DFLAGS=$(DFLAGS)
	@echo LINKFLAGS -z noexecstack -EL --fix-cortex-a53-843419 --warn-shared-textrel -z now -z relro -z max-page-size=4096 --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m aarch64linux -shared
	@echo ANDROID_LDFLAGS=$(ANDROID_LDFLAGS)
	@echo OBJS=$(OBJS)

clean-android:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(LIBRARY)
	$(RM) $(LIBOBJECT)

.PHONY: clean-android

clean: clean-android

${call DDEPS,$(DBUILD),$(DFILES)}


endif

#"/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/ld" -z noexecstack -EL --fix-cortex-a53-843419 --warn-shared-textrel -z now -z relro -z max-page-size=4096 --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m aarch64linux -shared -o bin/libtest-aarch64.so /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtbegin_so.o -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/aarch64 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/aarch64-linux-android/4.9.x -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib -soname bin/libtest-aarch64.so bin/libtest-aarch64.o /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a -l:libunwind.a -ldl -lc /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a -l:libunwind.a -ldl /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtend_so.o

#"/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/ld" -z noexecstack -EL --fix-cortex-a53-843419 --warn-shared-textrel -z now -z relro -z max-page-size=4096 --hash-style=gnu --enable-new-dtags --eh-frame-hdr -m aarch64linux -shared -o bin/libtest-aarch64.so /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtbegin_so.o -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/aarch64 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../lib/gcc/aarch64-linux-android/4.9.x -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30 -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android -L/home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib -soname bin/libtest-aarch64.so bin/libtest-aarch64.o /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a -l:libunwind.a -ldl -lc /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux/libclang_rt.builtins-aarch64-android.a -l:libunwind.a -ldl /home/carsten/Android/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/lib/aarch64-linux-android/30/crtend_so.o
