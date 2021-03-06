Diving Beet
===========

Diving Beet is a port of [Falling
Turnip](https://github.com/tranma/falling-turnip) from Haskell to
[Futhark](https://futhark-lang.org) and Python (or Go; see below).  It
is a physics imitation that uses cellular automata to implement
fascimiles of gravity and (al)chemical interactions between various
elements.  For example, water plus fire gives steam, lava melts sand
and metal (the latter at a slower rate), plants grow into water, etc.

You can look at a [video of it in
action](http://sigkill.dk/junk/diving-beet.webm) - note that the
choppiness (especially near the end) is due to the screen recorder not
being able to keep up (it runs out of memory and starts writing to
disk).

Usage
-----

Just `make run`, although you'll need the Futhark compiler installed.
You can insert particles by left-clicking, although you can't
overwrite anything that's already there.  Right-click to delete
particles.  Use the left/right arrow keys to select the particle to
insert, and the scroll wheel to control the modification radius.

Usage with Go
-------------

Diving Beet has also been implemented with a GUI written in Go.  This
performs much better on some systems.  Make sure you have Go and the
packages `github.com/veandco/go-sdl2/sdl` and
`github.com/veandco/go-sdl2/ttf` installed, and then run:

```
$ make diving-beet
$ ./diving-beet
```
