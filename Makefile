# Based on https://github.com/rowanmanning/make/blob/8628a5c2f7542def689bd4718f6bca2b8f7db533/javascript/index.mk

dist/Main.js: install
	@npx elm make app/Main.elm --output=dist/Main.js
	@$(TASK_DONE)

dist/Main.optimized.js dist/Main.optimized.min.js: install
	@./optimize.sh
	@$(TASK_DONE)

# Clean the Git repository
.PHONY: clean
clean:
	@git clean -fxd
	@$(TASK_DONE)

# Install dependencies
.PHONY: install
install: node_modules
	@$(TASK_DONE)

# Run npm install if package.json has changed more
# recently than node_modules
node_modules: package.json
	@npm install
	@$(TASK_DONE)

TASK_DONE = echo "✓ $@ done"
