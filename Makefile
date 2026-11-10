EMACS ?= emacs
ELPA   = $(HOME)/.emacs.d/elpa

AGENT_SHELL = $(shell ls -td $(ELPA)/agent-shell-2* | head -1)
SHELL_MAKER = $(shell ls -td $(ELPA)/shell-maker-* | head -1)
ACP         = $(shell ls -td $(ELPA)/acp-*         | head -1)

BATCH = $(EMACS) --batch -Q \
	-L $(AGENT_SHELL) -L $(SHELL_MAKER) -L $(ACP) -L .

.PHONY: test compile firefox clean

test:
	$(BATCH) -l test/agent-shell-browser-test.el -f ert-run-tests-batch-and-exit

compile:
	$(BATCH) --eval "(setq byte-compile-error-on-warn t)" \
	         -f batch-byte-compile agent-shell-browser.el agent-shell-browser-dashboard.el

firefox:
	rm -rf build/firefox && mkdir -p build && cp -R extension build/firefox
	python3 -c 'import json, sys; p = sys.argv[1]; m = json.load(open(p)); m["background"] = {"scripts": ["background.js"]}; json.dump(m, open(p, "w"), indent=2)' build/firefox/manifest.json

clean:
	rm -rf *.elc test/*.elc build
