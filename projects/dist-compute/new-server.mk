
INSTALL=$(WORKDIR)/godi
GODI_ROCKET="http://download.camlcity.org/download/godi-rocketboost-20110811.tar.gz"
export PATH:=$(INSTALL)/sbin:$(INSTALL)/bin:$(PATH)

goditar=$(shell basename $(GODI_ROCKET))
godidir=$(shell echo $(goditar) | sed -e s/.tar.gz//)

.PHONY: all ubuntu_packages godi_download godi_packages lda_packages wikitrust_src

all: godi_packages lda_packages wikitrust_src

ubuntu_packages:
	sudo aptitude install gcc m4 libmysqlclient-dev
	sudo aptitude install ec2-api-tools ec2-ami-tools

godi_download:
	rm -f $(goditar)
	wget $(GODI_ROCKET)
	rm -rf $(godidir)
	tar -xzvf $(goditar)
	rm -rf $(goditar)

$(godidir):
	$(MAKE) godi_download

$(INSTALL)/sbin/godi_console: ubuntu_packages godi_download
	cd $(godidir); ./bootstrap --prefix $(INSTALL)
	echo "GODI_BASEPKG_PCRE=yes" >> $(INSTALL)/etc/godi.conf
	cd $(godidir); ./bootstrap_stage2
	rm -rf $(godidir)

godi_packages: $(INSTALL)/sbin/godi_console
	godi_console perform -newer -build godi-extlib
	godi_console perform -newer -build godi-findlib
	godi_console perform -newer -build godi-json-static
	godi_console perform -newer -build godi-json-wheel
	godi_console perform -newer -build godi-ocaml-mysql
	godi_console perform -newer -build godi-ocamlnet
	godi_console perform -newer -build godi-pcre
	godi_console perform -newer -build godi-sexplib
	godi_console perform -newer -build godi-type-conv
	godi_console perform -newer -build godi-xml-light
	godi_console perform -newer -build godi-zip

lda_packages:
	git clone http://github.com/collaborativetrust/OcamlLdaLibs.git
	cd OcamlLdaLibs; make all
	rm -rf OcamlLdaLibs

wikitrust_src: $(SRCDIR)
	cd $(SRCDIR); git checkout thumper-vandalrep
	cd $(SRCDIR); git fetch spcr
	cd $(SRCDIR); git rebase spcr/thumper-vandalrep
	cd $(SRCDIR); make allopt
	mkdir -p $(WORKDIR)/cmds
	mkdir -p $(WORKDIR)/stats
	mkdir -p $(WORKDIR)/splits
	cp -a $(SRCDIR)/analysis/evalwiki $(WORKDIR)/cmds


$(WORKDIR)/WikiTrust:
	mkdir -p $(WORKDIR)
	cd $(WORKDIR); git clone thumper@spcr.fastcoder.net:/home/git/ucsc/wikitrust/WikiTrust.git
	cd $(WORKDIR)/WikiTrust ; git remote add spcr thumper@spcr.fastcoder.net:/home/git/ucsc/wikitrust/WikiTrust.git
	cd $(WORKDIR)/WikiTrust ; git checkout -b thumper-vandalrep spcr/thumper-vandalrep

