.PHONY: clean

export TEXINPUTS=./memoir:./apacite::
export BSTINPUTS=./apacite


all: logbook.pdf


clean:
	./latexmk -c
	rm -f *.log *.aux *.dvi *.bbl *.blg *~  *.brf *.out *.pdf

APACITE=apacite/apacite.bst
$(APACITE):
	cd apacite; latex apacite.ins

MEMOIR=memoir/memoir.cls
$(MEMOIR):
	cd memoir; latex memoir.ins

logbook.dvi: $(APACITE) $(MEMOIR) logbook*.tex *.tex */*.tex *.bib

.SUFFIXES: .ps .dvi .aux .tex .pdf .log .bib .bbl .xml
.PRECIOUS: %.dvi

# erase the default rule for building dvi files
# The default rule always just tries to run tex, which isn't
# what I want to do, in this case.
%.dvi: %.tex
	./latexmk $<

#%.pdf: %.tex %.bib
#	./latexmk -pdf $<

%.pdf: %.dvi
	dvipdf $<

%.ps: %.dvi
	dvips $<

