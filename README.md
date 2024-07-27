# tulars

![.github/workflows/make.yml](https://github.com/r-k-b/tulars/actions/workflows/nix.yml/badge.svg)

Experimentation with simple Utility Function-based agents. [(Demo)](https://tulars-5f1d1.firebaseapp.com) 

E.g., how do we specify rich, sequential and/or parallel behaviours that 
are robust to changing environments and dynamic goals? 

# running direct from GitHub

You'll need [Nix] installed.

```shell
$ nix run github:r-k-b/tulars
```


# building with Nix

```shell
$ nix build github:r-k-b/tulars

$ xdg-open result/index.html
```


# testing

Run `nix flake check github:r-k-b/tulars`.

TODO: include these in `nix flake check`:

- elm-test
- elm-review
- an elm-format check
- style checks for all the other files?


# keeping dependencies up to date

dependabot should keep the elm.json dependencies up to date;
to keep the elm2nix / elm-srcs.nix dependencies up to date,
run `update-elm-nix-deps`.

NB, these commands assume you've entered the provided dev shell.
`direnv allow` or `nix develop` should get you there.


# integration tests

Not part of the default test run, yet.

While the site is running on `localhost:8000` (perhaps via `liveDev`), run:

    Cypress open


# misc

[Nix]: https://nixos.org/

[Verlet integration](https://en.wikipedia.org/wiki/Verlet_integration)

[GameAIPro: Intro to Utility Theory (PDF)](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf)

[Elm]: http://elm-lang.org/


## inspirations

[Creeper World](https://knucklecracker.com/)
[Globulation](https://globulation2.org/wiki/Main_Page)
[Incremancer](https://github.com/jamesmgittins/incremancer)
[Kenshi](https://lofigames.com/)
[Rimworld](https://rimworldgame.com/)
