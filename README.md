# gcr.nvim



## Development

### Environment

Assuming you have plenary in `../plenary.nvim`, you can debug inside of:

``` bash
nvim --headless --noplugin -u tests/minimal_init.vim
```

After making changes use `,,x` to reload the plugin

### Run tests

Running tests requires you to [install act](https://github.com/nektos/act#installation) to run the Github actions locally.  
After installing, you can simply run `act -r` at the top level of this project to run the tests.
