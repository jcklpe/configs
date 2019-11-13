XDG_CONFIG_HOME ?= ${HOME}/.config
RANGER_PLUGINS_DIR = ${XDG_CONFIG_HOME}/ranger/plugins

.PHONY: install
install:
	@sh -c "test -d ${RANGER_PLUGINS_DIR} || mkdir -p ${RANGER_PLUGINS_DIR} && \
		cp jump.py ${RANGER_PLUGINS_DIR}"
