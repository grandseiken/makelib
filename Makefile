# Input variables for Makefile.makelib:
#
# ==== Directories ====
#   GENDIR: directory for generated files.
#   OUTDIR_TMP: directory for build artifacts.
#
# ==== File listings ====
#   ALL_FILES: all files for utility targets (add, todo, wc).
#   CC_SOURCE_FILES: C++ source files.
#   CC_GENERATED_FILES:
#     generated C++ source files; prerequisites for calculating C++ header
#     inclusion dependency graph.
#
# ==== Prerequisites ====
#   CC_OBJECT_FILE_PREREQS: prerequisites for compiling C++ source files.
#   DISABLE_CC_DEPENDENCY_ANALYSIS:
#     set to 'true' to disable dependency analysis (e.g. to avoid this step when
#     building some unrelated target).
#
# ==== C++ settings ====
#   CXX: C++ compiler.
#   CFLAGS: passed to C++ compiler (for header inclusion and compilation).
#   WFLAGS: passed to C++ compiler for compiling (non-generated) files.

# Disable standard implicit rules.
.SUFFIXES:

# Always default to the 'all' target.
.PHONY: default
default: all

# Utility targets.
add:
	git add $(ALL_FILES)
.PHONY: todo
todo:
	@grep --color -n "\bT[O]D[O]\b" $(ALL_FILES)
.PHONY: wc
wc:
	wc $(ALL_FILES)

# Compilers and interpreters.
export SHELL=/bin/sh

# Calculated filesets.
.PRECIOUS: $(CC_GENERATED_FILES)
CC_ALL_FILES=$(CC_SOURCE_FILES) $(CC_GENERATED_FILES)
CC_DEP_FILES=\
  $(addprefix $(OUTDIR_TMP)/,$(addsuffix .deps,$(CC_ALL_FILES)))
CC_OBJECT_FILES=\
  $(addprefix $(OUTDIR_TMP)/,$(addsuffix .o,$(CC_ALL_FILES)))

# Recursively include dependency analysis outputs.
ifneq ('$(DISABLE_CC_DEPENDENCY_ANALYSIS)', 'true')
-include $(CC_DEP_FILES)
endif

# Object files. References dependencies -- e.g. libraries that must be built
# before their header files are available -- in CC_OBJECT_FILE_PREREQS.
$(CC_OBJECT_FILES): $(OUTDIR_TMP)/%.o: \
  $(OUTDIR_TMP)/%.build $(OUTDIR_TMP)/%.mkdir $(CC_OBJECT_FILE_PREREQS)
	SOURCE_FILE=$(subst $(OUTDIR_TMP)/,,./$(<:.build=)); \
	    echo Compiling $$SOURCE_FILE; \
	    $(CXX) -c $(CFLAGS) $(if $(findstring /$(GENDIR)/,$@),,$(WFLAGS)) \
	    -o $@ $$SOURCE_FILE

# Dependency generation. Each source file generates a corresponding .deps file
# (a Makefile containing a .build target), which is then included. Inclusion
# forces regeneration via the rules provided. Deps rule depends on same .build
# target it generates. When the specific .build target doesn't exist, the
# default causes everything to be generated.
.SECONDEXPANSION:
$(CC_DEP_FILES): $(OUTDIR_TMP)/%.deps: \
  $(OUTDIR_TMP)/%.build $(OUTDIR_TMP)/%.mkdir $(CC_GENERATED_FILES) \
  $$(subst \
  $$(OUTDIR_TMP)/,,$$($$(subst .,_,$$(subst /,_,$$(subst \
  $$(OUTDIR_TMP)/,,./$$(@:.deps=))))_LINK:.o=))
	SOURCE_FILE=$(subst $(OUTDIR_TMP)/,,./$(@:.deps=)); \
	    echo Generating dependencies for $$SOURCE_FILE; \
	    $(CXX) $(CFLAGS) -o $@ -MM $$SOURCE_FILE && \
	    sed -i -e 's/.*\.o:/$(subst /,\/,$<)::/g' $@
	echo "	@touch" $< >> $@

# Dependency on source files.
.PRECIOUS: $(OUTDIR_TMP)/%.build
$(OUTDIR_TMP)/%.build: \
  ./% $(OUTDIR_TMP)/%.mkdir
	touch $@

# Ensure a directory exists.
.PRECIOUS: ./%.mkdir
./%.mkdir:
	mkdir -p $(dir $@)
	touch $@
