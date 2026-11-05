.DEFAULT_GOAL := help
.NOTPARALLEL:
PYTHON ?= python3
.PHONY: help doctor init build plan infra configure seed up status verify test down destroy reset
help doctor init build plan infra configure seed up status verify test down destroy reset:
	@$(PYTHON) scripts/lab.py $@
