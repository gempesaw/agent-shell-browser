EMACS ?= emacs
ELPA   = $(HOME)/.emacs.d/elpa

AGENT_SHELL = $(shell ls -td $(ELPA)/agent-shell-2* | head -1)
SHELL_MAKER = $(shell ls -td $(ELPA)/shell-maker-* | head -1)
ACP         = $(shell ls -td $(ELPA)/acp-*         | head -1)

BATCH = $(EMACS) --batch -Q \
	-L $(AGENT_SHELL) -L $(SHELL_MAKER) -L $(ACP) -L .

.PHONY: test compile clean

test:
	$(BATCH) -l test/agent-shell-browser-test.el -f ert-run-tests-batch-and-exit

compile:
	$(BATCH) --eval "(setq byte-compile-error-on-warn t)" \
	         -f batch-byte-compile agent-shell-browser.el agent-shell-browser-dashboard.el

clean:
	rm -f *.elc test/*.elc
