define dir.self
${dir ${lastword $(MAKEFILE_LIST)}}${strip $1}
endef

define rm.dir
$(PRECMD)mkdir -p $(DIR_TRASH)/${strip $1}
${call log.kvp, Trashed, ${strip $1}}
$(PRECMD)cp -rf ${strip $1} $(DIR_TRASH)/${strip $1} 2> /dev/null || true &
$(PRECMD)rm -rf ${strip $1} 2> /dev/null || true &
endef