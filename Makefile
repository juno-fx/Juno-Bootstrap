.PHONY: package

package:
	@rm -rf .orion-helper-scripts orion-install-helper
	@mkdir -p .orion-helper-scripts
	@git worktree add -f .orion-helper-scripts/bootstrap HEAD
	@chmod -R 775 .orion-helper-scripts
	@shar -T -D -Q .orion-helper-scripts/ | head -n -1 > orion-install-helper && echo ".orion-helper-scripts/bootstrap/helper/install.sh" >> orion-install-helper
	@echo The installer was packaged into: orion-install-helper

lint:
	find -name "*.sh" -not -path "./.devbox/*" | xargs shellcheck -x
