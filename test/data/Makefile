
#
# 'make' generates try01_tmpl.html by latex-compiling try01_tmpl.tex and pandoc-converting
# it and correcting it with this tool.
#
# You may run `make clean` before `make`.
#
# Environmental variable LATEX should points the LaTeX command in your environment.
# If environmental variable NOLATEX is set, LaTeX compiling is skipped,
# and try01_tmpl.aux is assumed to exist in the current directory.
#
# USAGE:  make NOLATEX=1 LATEX=platex

ALL	= try01_tmpl.html

objs	= 
auxfile = try01_tmpl.aux

.SUFFIXES:	.so .o .c .f

#.o.so:
#	${LD} ${LFLAGS} -o $@ $< ${LINK_LIB}

all: ${ALL}

try01_tmpl.html: try01_tmpl.tex
	if [ -z "$${NOLATEX}" ]; then ${LATEX} $<; ${LATEX} $<; fi; if [ -e ${auxfile} ]; then echo "${auxfile} is found. Creating HTML."; pandoc --lua-filter ./shifted-numbered-headings.lua -s -N --section-divs -t html5 --toc --reference-location=block --mathml $< | RUBYLIB=../../lib:$$RUBYLIB ../../bin/pandoc_refeq_mathml --aux ${auxfile} > $@; echo "$@ is created."; else echo "aux file (${auxfile}) is not found." 2>&1; exit 1; fi

.PHONY: clean
clean:
	$(RM) try01_tmpl.html try01_tmpl.dvi try01_tmpl.log try01_tmpl.out try01_tmpl.pdf try01_tmpl.toc; if [ -e ${auxfile} ]; then echo "NOTE: ${auxfile} is still present."; fi

