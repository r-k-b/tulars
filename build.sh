set -euo pipefail

src="app/Main.elm"
js="./dist/main.js"

elm make $src --output=$js $@
