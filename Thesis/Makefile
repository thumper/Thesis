.PHONY: clean

export TEXINPUTS=./memoir:./newalg::


all: paper.pdf


clean:
	latexmk -c
	rm -f *.log *.aux *.dvi *.bbl *.blg *~  *.brf *.out *.pdf

paper.dvi: paper*.tex paper-*/*.tex *.sty bib/*.bib part-*/*.tex

.SUFFIXES: .ps .dvi .aux .tex .pdf .log .bib .bbl .xml
.PRECIOUS: %.dvi

# erase the default rule for building dvi files
# The default rule always just tries to run tex, which isn't
# what I want to do, in this case.

paper.pdf: paper*.tex paper-*/*.tex *.sty bib/*.bib part-*/*.tex
	latexmk -pdfdvi $<

#%.dvi: %.tex
#	latexmk $<
#
#%.pdf: %.dvi
#	dvipdf $<
#
#%.ps: %.dvi
#	dvips $<

