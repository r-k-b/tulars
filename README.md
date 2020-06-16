# tulars

![.github/workflows/make.yml](https://github.com/r-k-b/tulars/workflows/.github/workflows/make.yml/badge.svg)

Experimentation with simple Utility Function-based agents. [(Demo)](https://tulars-5f1d1.firebaseapp.com) 

E.g., how do we specify rich, sequential and/or parallel behaviours that 
are robust to changing environments and dynamic goals? 


# building

(requires git, node.js 10+, and [Elm] 0.19)

`git clone git@github.com:r-k-b/tulars.git`

`cd tulars`

`npm install`

Then, either run `npm run live`, or open one of these in a browser:

- `dist/index.html`
- `dist/debug.html`
- `dist/optimized.html`


# testing

Run `npm test`.


# integration tests

Not part of the default `npm test`, yet.

While the site is running on `localhost:8000` (perhaps via `npm run live`), run:

    npm run cypress:open


# misc

[Verlet integration](https://en.wikipedia.org/wiki/Verlet_integration)

[GameAIPro: Intro to Utility Theory (PDF)](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf)

[Elm]: http://elm-lang.org/
