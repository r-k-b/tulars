
set -e

src="app/Main.elm"
js="./dist/main.debug.js"

elm make --debug $src --output=$js $@

# Create a copy of index.html that points to the debug output
sed "s/main.js/main.debug.js/" dist/index.html > dist/debug.html
