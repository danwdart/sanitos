# Gwallgofrwydd

(Welsh for "insanity").

A hobby distro of Linux, with some crazy things added and sensible things removed.

Superuser account is "joshua" with no password by default.

## Principles

Least possible software set to ensure functionality

As few libraries as possible

Static builds (for now).

## Building

Grab the sources

`git submodule init`

`git submodule update`

Make the lot

`make`

Test in kvm/qemu:

`make qemu`

