# gcr.nvim

Easily resolve git conflicts without leaving Neovim's buffers

## Development

### Environment

Requires plenary in the parent directory (`../plenary.nvim`), which you can get by running:

``` bash
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim ../plenary.nvim
```

Once you have plenary in `../plenary.nvim`, you can debug the plugin by running:

``` bash
nvim --noplugin -u tests/minimal_init.vim
```

After making changes use `,,x` to reload the plugin

### Making a Git repo with a conflict

Simply run `./make_bad_merge.sh` and a new repo `badmerge` will be made containing a file `conflicted` containing conflicts.

To quickly edit this file you can run:

``` bash
nvim --noplugin -u tests/minimal_init.vim badmerge/conflicted
```

### Run tests

Running tests requires you to [install act](https://github.com/nektos/act#installation) to run the Github actions locally.  
After installing, you can simply run `act -r` at the top level of this project to run the tests.
