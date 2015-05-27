# Input variables for Makefile.makelib:
#
# ==== General ====
#   DEBUG: controls defaults of some other variables below.
#
# ==== Directories ====
#   OUTDIR: directory for build output.
#   GENDIR: directory for generated files.
#
#     If not defined, OUTDIR defaults to Release or Debug depending on the value
#     of DEBUG, and GENDIR defaults to ./gen.
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
#   CFLAGS_EXTRA: same as CFLAGS, but can be set without overriding defaults.
#
#     If not defined, CFLAGS and WFLAGS have reasonable defaults based on the
#     value of DEBUG.

# Disable standard implicit rules.
.SUFFIXES:

# Always default to the 'all' target.
.PHONY: default
default: all

# Ensure target directory exists (use as first line of recipe).
MKDIR=@mkdir -p $(@D)

# Utility targets.
ifdef ALL_FILES
add:
	git add $(ALL_FILES)
.PHONY: todo
todo:
	@grep --color -n "\bT[O]D[O]\b" $(ALL_FILES)
.PHONY: wc
wc:
	wc $(ALL_FILES)
endif

# Compilers and interpreters.
export SHELL=/bin/sh

# Variable defaults.
ifndef GENDIR
  GENDIR=./gen
endif
ifdef DEBUG
  ifndef OUTDIR
    OUTDIR=./Debug
  endif
  ifndef CFLAGS
    CFLAGS=-Og -g -ggdb -DDEBUG
  endif
  ifndef WFLAGS
    WFLAGS=-Werror -Wall -Wextra -Wpedantic
  endif
else
  ifndef OUTDIR
    OUTDIR=./Release
  endif
  ifndef CFLAGS
    CFLAGS=-O3 -DNDEBUG
  endif
  ifndef WFLAGS
    WFLAGS=-Wall -Wextra -Wpedantic
  endif
endif

# Gives the object file for each source file.
src_to_o=$(addprefix $(OUTDIR_TMP)/,$(addsuffix .o,$1))

# Directories.
OUTDIR_TMP=$(OUTDIR)/build

# Calculated filesets.
.PRECIOUS: $(CC_GENERATED_FILES)
CC_ALL_FILES=$(CC_SOURCE_FILES) $(CC_GENERATED_FILES)
CC_DEP_FILES=\
  $(addprefix $(OUTDIR_TMP)/,$(addsuffix .deps,$(CC_ALL_FILES)))
CC_OBJECT_FILES=$(call src_to_o,$(CC_ALL_FILES))

# Recursively include dependency analysis outputs.
ifneq ('$(DISABLE_CC_DEPENDENCY_ANALYSIS)', 'true')
-include $(CC_DEP_FILES)
endif

# Object files. References dependencies -- e.g. libraries that must be built
# before their header files are available -- in CC_OBJECT_FILE_PREREQS.
$(CC_OBJECT_FILES): $(OUTDIR_TMP)/%.o: \
  $(OUTDIR_TMP)/%.build $(CC_OBJECT_FILE_PREREQS)
	$(MKDIR)
	SOURCE_FILE=$(subst $(OUTDIR_TMP)/,,./$(<:.build=)); \
	    echo Compiling $$SOURCE_FILE; \
	    $(CXX) -c $(CFLAGS) $(CFLAGS_EXTRA) \
	    $(if $(findstring /$(GENDIR)/,$@),,$(WFLAGS)) -o $@ $$SOURCE_FILE

# Dependency generation. Each source file generates a corresponding .deps file
# (a Makefile containing a .build target), which is then included. Inclusion
# forces regeneration via the rules provided. Deps rule depends on same .build
# target it generates. When the specific .build target doesn't exist, the
# default causes everything to be generated.
# TODO: also generate link dependencies as best as possible.
.SECONDEXPANSION:
$(CC_DEP_FILES): $(OUTDIR_TMP)/%.deps: \
  $(OUTDIR_TMP)/%.build $(CC_GENERATED_FILES)
	$(MKDIR)
	SOURCE_FILE=$(subst $(OUTDIR_TMP)/,,./$(@:.deps=)); \
	    echo Generating dependencies for $$SOURCE_FILE; \
	    $(CXX) $(CFLAGS) $(CFLAGS_EXTRA) -o $@ -MM $$SOURCE_FILE && \
	    sed -i -e 's/.*\.o:/$(subst /,\/,$<)::/g' $@
	echo "	@touch" $< >> $@

# Dependency on source files (default target; overridden by dependency
# generation).
.PRECIOUS: $(OUTDIR_TMP)/%.build
$(OUTDIR_TMP)/%.build: ./%
	$(MKDIR)
	touch $@
