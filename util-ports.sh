# ports_config_load
#
# Handle ports specific configuration.
ports_config_load() {
	# Sanitize the inherited environment.
	unset MAKEFLAGS PKG_PATH
}
