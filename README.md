# tulars

![.github/workflows/make.yml](https://github.com/r-k-b/tulars/workflows/.github/workflows/make.yml/badge.svg)

Experimentation with simple Utility Function-based agents. [(Demo)](https://tulars-5f1d1.firebaseapp.com) 

E.g., how do we specify rich, sequential and/or parallel behaviours that 
are robust to changing environments and dynamic goals? 

# running direct from GitHub

```shell
$ nix run github:r-k-b/tulars
```

# building with Nix

```shell
$ nix build github:r-k-b/tulars

$ xdg-open result/index.html
```


# building (non-nix)

(requires git, node.js 10+, and [Elm] 0.19)

`git clone git@github.com:r-k-b/tulars.git`

`cd tulars`

`npm install`

Then, either run `npm run live`, or open one of these in a browser:

- `dist/index.html`
- `dist/debug.html`
- `dist/optimized.html`


# testing

Run `npm test` and/or `nix flake check`.


# keeping dependencies up to date

dependabot should keep the package.json and elm.json dependencies up to date;
to keep the elm2nix / elm-srcs.nix dependencies up to date,
run `update-elm-nix-deps`. 


# integration tests

Not part of the default `npm test`, yet.

While the site is running on `localhost:8000` (perhaps via `npm run live`), run:

    npm run cypress:open


# misc

[Verlet integration](https://en.wikipedia.org/wiki/Verlet_integration)

[GameAIPro: Intro to Utility Theory (PDF)](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf)

[Elm]: http://elm-lang.org/


## inspirations

[Creeper World](https://knucklecracker.com/)
[Globulation](https://globulation2.org/wiki/Main_Page)
[Incremancer](https://github.com/jamesmgittins/incremancer)
[Kenshi](https://lofigames.com/)
[Rimworld](https://rimworldgame.com/)
