UNITS_DEFINED := _
UNIT_PREFIX_LIB := lib-
UNIT_PREFIX_BIN := bin-
UNIT_PREFIX_WRAP := wrap-
UNIT_PREFIX_LIB_TARGET := libtagion
UNIT_PREFIX_BIN_TARGET := tagion
UNIT_PREFIX_WRAP_TARGET := wrap-

# 
# Interface
# 
# Unit declaration
define unit.lib
${eval ${call _unit.lib, $1}}
endef

define unit.bin
${eval ${call _unit.lib, $1}}
endef

define unit.wrap
${eval ${call _unit.lib, $1}}
endef

# Unit declaration of dependencies
define unit.dep.lib
${eval ${call _unit.dep.lib, $1}}
endef

define unit.dep.wrap
${eval ${call _unit.dep.lib, $1}}
endef

# Unit declaration ending
define unit.end
${eval ${call _unit.end.safe}}
endef

# 
# Implementation
# 
define _unit.vars.reset
UNIT :=
UNIT_PREFIX :=
UNIT_PREFIX_TARGET :=
UNIT_DEPS :=
UNIT_DEPS_PREFIXED :=
UNIT_DEPS_PREFIXED_TARGETS :=
endef

define _unit.lib
${info -> start unit lib ${strip $1}, at this point already defined: $(UNITS_DEFINED)}
${call _unit.vars.reset}
UNIT := ${strip $1}
UNIT_PREFIX := $(UNIT_PREFIX_LIB)
UNIT_PREFIX_TARGET := $(UNIT_PREFIX_LIB_TARGET)
endef

define _unit.bin
${info -> start unit bin ${strip $1}, at this point already defined: $(UNITS_DEFINED)}
${call _unit.vars.reset}
UNIT := ${strip $1}
UNIT_PREFIX := $(UNIT_PREFIX_BIN)
UNIT_PREFIX_TARGET := $(UNIT_PREFIX_BIN_TARGET)
endef

define _unit.wrap
${info -> start unit wrap ${strip $1}, at this point already defined: $(UNITS_DEFINED)}
${call _unit.vars.reset}
UNIT := ${strip $1}
UNIT_PREFIX := $(UNIT_PREFIX_WRAP)
UNIT_PREFIX_TARGET := $(UNIT_PREFIX_WRAP_TARGET)
endef

# Unit declaration of dependencies
define _unit.dep.lib
${info -> add lib ${strip $1} to $(UNIT)}
UNIT_DEPS += ${strip $1}
UNIT_DEPS_PREFIXED += $(UNIT_PREFIX_LIB)${strip $1}
UNIT_DEPS_PREFIXED_TARGETS += $(UNIT_PREFIX_LIB_TARGET)${strip $1}
endef

define _unit.dep.wrap
${info -> add wrap ${strip $1} to $(UNIT)}
UNIT_DEPS += ${strip $1}
UNIT_DEPS_PREFIXED += $(UNIT_PREFIX_WRAP)${strip $1}
UNIT_DEPS_PREFIXED_TARGETS += $(UNIT_PREFIX_WRAP_TARGET)${strip $1}
endef

# Unit declaration ending
define _unit.end.safe
# Will not execute twice (need in rare cases with circular dependencies):
${eval UNIT_DEFINED_BLOCK := ${findstring $(UNIT_PREFIX)$(UNIT), $(UNITS_DEFINED)}}
${if $(UNIT_DEFINED_BLOCK), , ${eval ${call _unit.end}}}
endef

define _unit.target.dep
$(UNIT_PREFIX_TARGET)$(UNIT):
	@echo "This is $(UNIT), it depends on $(UNIT_DEPS_PREFIXED_TARGETS)"
endef

define _unit.target.compile
$(UNIT_PREFIX_TARGET)$(UNIT): $(UNIT_DEPS_PREFIXED_TARGETS)
	@echo "This is $(UNIT), it depends on $(UNIT_DEPS_PREFIXED_TARGETS)"
endef

define _unit.end
${info -> $(UNIT) defined, deps: $(UNIT_DEPS)}

${eval UNITS_DEFINED += $(UNIT_PREFIX)$(UNIT)}
${eval UNIT_IS_COMPILE_TARGET := ${findstring $(UNIT_PREFIX)$(UNIT), $(COMPILE_TARGETS_DIRS)}}

${if $(UNIT_IS_COMPILE_TARGET), ${eval ${call _unit.target.compile}}, ${eval ${call _unit.target.dep}}}

# Remove dependencies that were already included:
${foreach UNIT_DEFINED, $(UNITS_DEFINED), ${eval UNIT_DEPS_PREFIXED := ${patsubst $(UNIT_DEFINED),,$(UNIT_DEPS_PREFIXED)}}}
# Include new dependencies:
${foreach UNIT_DEP_PREFIXED, $(UNIT_DEPS_PREFIXED), ${eval include $(DIR_SRC)/$(UNIT_DEP_PREFIXED)/context.mk}}
endef

