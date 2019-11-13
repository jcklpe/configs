# Jump Ranger
This is [jump][] plug-in that integrates [ranger][] with [jump][] and exposes
the `:j` helper to [ranger][].

## Installation
Install with `make install`.

## zsh integration
you can use this ranger integration with zsh using the zsh integration. Just source the file in your .zshrc
The zsh integration allows you to call a function called "r" which will fuzzy search using jump and then open the directory to ranger. 

zsh integration was based off the [autojump ranger zsh integration](https://github.com/fdw/ranger-autojump).

[jump]: https://github.com/gsamokovarov/jump
[ranger]: https://github.com/ranger/ranger

