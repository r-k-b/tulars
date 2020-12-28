# Based on the script at https://elm-lang.org/0.19.0/optimize

set -e

src="app/Main.elm"
js="./dist/main.optimized.js"
min="./dist/main.optimized.min.js"

elm make --optimize $src --output=$js $@

uglifyjs $js --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' \
    | uglifyjs --mangle --output=$min

echo "Initial size: $(cat $js | wc -c) bytes  ($js)"
echo "Minified size:$(cat $min | wc -c) bytes  ($min)"
echo "Gzipped size: $(cat $min | gzip -c | wc -c) bytes"

# Create a copy of index.html that points to the optimized, minified output
sed "s/main.js/main.optimized.min.js/" dist/index.html > dist/optimized.html
