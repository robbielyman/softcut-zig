# softcut-zig

this repository contains C and Zig bindings for [softcut-lib](https://github.com/monome/softcut-lib),
a C++ audio buffer manipulation library by [Ezra Buchla](https://github.com/catfact) 
for [monome](https://monome.org).

it also contains `softcut-client`, 
a minimal Zig port of `softcut_jack_osc`,
which is a JACK client making use of `softcut-lib` written by Ezra Buchla.
rather than JACK, `softcut-client` uses [libsoundio](https://github.com/andrewrk/libsoundio).
like `softcut_jack_osc`, `softcut-client` is controlled over OSC.
on successful startup, `softcut-client` prints the list of OSC messages it responds to.

`softcut-client` is beta software.

## building

building requires a nightly build of [Zig](https://ziglang.org/);
the minimum Zig version required is `0.12.0-dev.2154+e5dc9b1d0`.

additional dependencies are `libsndfile`, `liblo`, and `libsoundio` (and their dependencies).
by default you are required to have these available on your system.
if you'd like, pass `-Dstatic=true` below to attempt to build `liblo` and `libsoundio` statically.
the number of softcut voices is configurable at compile time with `-Dvoices`, and defaults to
`-Dvoices=6`.

With Zig available on your `$PATH`, execute the following command in the repository root.

```
zig build
```

to build `softcut-lib` and `softcut-client`.
as is typical with zig projects, `softcut-client` is installed to `./zig-out/bin` by default.
add this to your path if you'd like, or symlink `./zig-out/bin/softcut-client` onto your path.

## usage

running `softcut-client` by default will print a list of suitable devices for you to choose from and exit.
after making a selection, rerun with, e.g. `softcut-client -i 1 -o 1`

after softcut is launched, control it by sending it OSC messages.
by default `softcut-client` listens on port 9999.

### limitations

48kHz sample rate is required when reading files as well as choosing an output device.
two buffers are available, with about 350 seconds of capacity each.
