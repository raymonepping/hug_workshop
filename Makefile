.DEFAULT_GOAL := help
.NOTPARALLEL:
PYTHON ?= python3
.PHONY: help doctor init build plan infra configure seed up status verify test down destroy reset persona test-browser
help doctor init build plan infra configure seed up status verify test down destroy reset persona test-browser:
	@$(PYTHON) scripts/lab.py $@
