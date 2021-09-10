local getenv = os.getenv
local Job = require'plenary.job'
local Path = require "plenary.path"
local api = vim.api
local get_cursor = api.nvim_win_get_cursor
local feedkeys = api.nvim_feedkeys
local replace_termcodes = api.nvim_replace_termcodes

local TMP = getenv('RUNNER_TEMP')
local REPO = getenv('GITHUB_WORKSPACE')
local ARTIFACTS = REPO .. '/tests/artifacts/'
local BADMERGE_REPO = TMP .. '/badmerge/'

local DEFAULT_CONFLICT = 'conflicted'
local CONFLICT_LINES = {
  3, 6, 8,
  14, 16, 18,
  24, 26, 28,
}
local CONFLICT_STARTS = {}
for index, value in ipairs(CONFLICT_LINES) do
  if (index - 1) % 3 == 0 then
    table.insert(CONFLICT_STARTS, value)
  end
end

local function run_target_script(script, name)
  return Job:new({
    command = ARTIFACTS .. script,
    cwd = TMP,
    args = name and { name },
    skip_validation = true,
  }):sync()
end

local function T(keys)
  return replace_termcodes(keys, true, false, true)
end

local function press_keys(keys)
  feedkeys(keys, "x", false)
end

local function setup_conflict_repo(name)
  return run_target_script('setup_conflict_repo.sh', name)
end

local function make_conflict(name, empty)
  if empty then
    Path:new(BADMERGE_REPO .. DEFAULT_CONFLICT):touch({parents = true})
  else
    run_target_script('make_conflict.sh', name)
  end
end

local function open_conflict(name)
  vim.cmd('e! ' .. BADMERGE_REPO .. name)
end

local function in_a(msg, fn)
  describe('in a ' .. msg, fn)
end

describe('gcr', function()
  require('gcr').setup()

  after_each(function ()
    run_target_script('remove_repo.sh')
  end)

  in_a('file with conflicts', function()
    before_each(function ()
      setup_conflict_repo(DEFAULT_CONFLICT)
      make_conflict(DEFAULT_CONFLICT)
      open_conflict(DEFAULT_CONFLICT)
    end)

    it('detects conflicts', function()
      assert.is_true(require('gcr').has_conflict())
    end)

    it('detects the correct conflict lines', function()
      assert.same(require('gcr').conflict_lines(), CONFLICT_LINES)
    end)

    describe('starting at the first line', function()
      before_each(function ()
        press_keys("1gg0")
      end)

      it('can jump 1 time to the 1st conflict', function()
        local cursor = get_cursor(0)
        assert.same(cursor, {1, 0})

        require('gcr').next_conflict()
        cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[1], 0})
      end)

      it('can jump 2 times to the 2nd conflict', function()
        local cursor = get_cursor(0)
        assert.same(cursor, {1, 0})

        require('gcr').next_conflict()
        require('gcr').next_conflict()
        cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[2], 0})
      end)

      it('can jump 3 times to the 3rd conflict', function()
        local cursor = get_cursor(0)
        assert.same(cursor, {1, 0})

        require('gcr').next_conflict()
        require('gcr').next_conflict()
        require('gcr').next_conflict()
        cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[3], 0})
      end)

      it('can wrap back to the last conflict', function()
        local cursor = get_cursor(0)
        assert.same(cursor, {1, 0})

        require('gcr').prev_conflict(true)
        cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[3], 0})
      end)
    end)

    describe('starting at the first conflict', function()
      before_each(function ()
        press_keys("1gg0")
        require('gcr').next_conflict()
      end)

      it('can wrap back to the last conflict', function()
        local cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[1], 0})

        require('gcr').prev_conflict(true)
        cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[3], 0})
      end)
    end)

    describe('starting at the last conflict', function()
      before_each(function ()
        press_keys("1gg0")
        require('gcr').prev_conflict(true)
      end)

      it('can wrap forward to the first conflict', function()
        local cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[3], 0})

        require('gcr').next_conflict(true)
        cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[1], 0})
      end)

      it('can jump back 1 time to the 2nd conflict', function()
        local cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[3], 0})

        require('gcr').prev_conflict()
        cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[2], 0})
      end)

      it('can jump back 2 times to the 1st conflict', function()
        local cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[3], 0})

        require('gcr').prev_conflict()
        require('gcr').prev_conflict()
        cursor = get_cursor(0)
        assert.same(cursor, {CONFLICT_STARTS[1], 0})
      end)
    end)
  end)

  in_a('a file with no conflicts', function()
    before_each(function ()
      setup_conflict_repo(DEFAULT_CONFLICT)
      open_conflict(DEFAULT_CONFLICT)
    end)

    it('detects no conflicts', function()
      assert.is_false(require('gcr').has_conflict())
    end)
  end)

  in_a('folder without git', function()
    before_each(function ()
      make_conflict(DEFAULT_CONFLICT, true)
      open_conflict(DEFAULT_CONFLICT)
    end)

    it('detects no conflicts', function()
      assert.is_false(require('gcr').has_conflict())
    end)
  end)

end)
