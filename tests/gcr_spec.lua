local getenv = os.getenv
local Job = require'plenary.job'
local Path = require "plenary.path"

local TMP = getenv('RUNNER_TEMP')
local REPO = getenv('GITHUB_WORKSPACE')
local ARTIFACTS = REPO .. '/tests/artifacts/'
local BADMERGE_REPO = TMP .. '/badmerge/'

local DEFAULT_CONFLICT = 'conflicted'

local function run_target_script(script, name)
  return Job:new({
    command = ARTIFACTS .. script,
    cwd = TMP,
    args = name and { name },
    skip_validation = true,
  }):sync()
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

describe('gcr', function()
  require('gcr').setup()

  after_each(function ()
    run_target_script('remove_repo.sh')
  end)

  it('detects conflicts when there are conflicts', function()
    setup_conflict_repo(DEFAULT_CONFLICT)
    make_conflict(DEFAULT_CONFLICT)
    open_conflict(DEFAULT_CONFLICT)
    assert.is_true(require('gcr').has_conflict())
  end)

  it('detects no conflicts when there is no repo', function()
    make_conflict(DEFAULT_CONFLICT, true)
    open_conflict(DEFAULT_CONFLICT)
    assert.is_false(require('gcr').has_conflict())
  end)

  it('detects no conflicts when there are none', function()
    setup_conflict_repo(DEFAULT_CONFLICT)
    open_conflict(DEFAULT_CONFLICT)
    assert.is_false(require('gcr').has_conflict())
  end)
end)
