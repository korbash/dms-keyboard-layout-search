.DEFAULT_GOAL := help
.PHONY: help test test-component test-live coverage reload status package

help:
	@printf '%s\n' 'Targets: test, test-component, test-live, coverage, reload, status, package'

test:
	python3 scripts/validate.py
	python3 -m unittest discover -s tests -p 'test_*.py'
	node --test tests/aliases.test.cjs

test-component:
	python3 scripts/test-component.py

test-live:
	node tests/live.cjs

coverage:
	python3 scripts/check-xkb-coverage.py

reload: test test-component
	python3 scripts/reload.py

status:
	dms ipc call keyboard-layout-search status

package: test test-component
	python3 scripts/package.py
