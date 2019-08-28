# This shell snippet unsets all variables/functions that can be used in
# a package template and can also be used in subpkgs.

## VARIABLES
unset -v conf_files mutable_files preserve triggers alternatives
unset -v depends run_depends replaces provides conflicts tags

# hooks/post-install/03-strip-and-debug-pkgs
unset -v nostrip nostrip_files

# hooks/pre-pkg/04-generate-runtime-deps
unset -v noverifyrdeps skiprdeps allow_unknown_shlibs shlib_requires

# hooks/pre-pkg/06-prepare-32bit
unset -v lib32depends lib32disabled lib32files lib32mode lib32symlinks

# hooks/pre-pkg/06-shlib-provides
unset -v noshlibprovides shlib_provides

# pkginst-triggers: system-accounts
unset -v system_accounts system_groups

# pkginst-triggers: font-dirs
unset -v font_dirs

# pkginst-triggers: xml-catalog
unset -v xml_entries sgml_entries xml_catalogs sgml_catalogs

# pkginst-triggers: pycompile
unset -v pycompile_version pycompile_dirs pycompile_module

# pkginst-triggers: dkms
unset -v dkms_modules

# pkginst-triggers: kernel-hooks
unset -v kernel_hooks_version

# pkginst-triggers: mkdirs
unset -v make_dirs

# pkginst-triggers: binfmts
unset -v binfmts

# pkginst-triggers: register-shell
unset -v register_shell
