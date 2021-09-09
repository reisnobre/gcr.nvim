local Job = require'plenary.job'
local Path = require "plenary.path"
local api = vim.api
local split = vim.split
local buf_filename = api.nvim_buf_get_name

local M = {}
local CHECK_TIMEOUT = 500

local NIL_CACHE = {}
M.NIL_CACHE = NIL_CACHE

local git_diff_check_jobs = {}

-- buffer file names to conflict marker lines
local conflict_cache = {}
M.conflict_cache = conflict_cache

local function parse_git_diff_check(lines)
  if lines == nil or #lines == 0 then
    return NIL_CACHE
  end
  local results = {}
  for _, line in ipairs(lines) do
    local parts = split(line, ':', true)
    if #parts == 3 or parts[3] == " leftover conflict marker" then
      table.insert(results, parts[2])
    end
  end
  if #results == 0 then
    return NIL_CACHE
  end

  return results
end

local function check_for_conflicts(filename, no_sync)
  -- TODO: New and empty buffers should be excluded before this point
  if filename == nil or #filename == 0 then
    return NIL_CACHE
  end

  if conflict_cache[filename] ~= nil then
    return conflict_cache[filename]
  end

  local job = git_diff_check_jobs[filename]
  -- assume there are no conflicts while still running without anything in cache
  if (job ~= nil) then return NIL_CACHE end

  local cwd = Path:new(filename):parent():absolute()

  job = Job:new({
    command = 'git',
    cwd = cwd,
    args = { 'diff', '--check', filename },
    skip_validation = true,
    on_exit = function(j, exit_code)
      if exit_code == 0 then
        conflict_cache[filename] = NIL_CACHE
      else
        conflict_cache[filename] = parse_git_diff_check(j:result())
      end

      git_diff_check_jobs[filename] = nil
    end
  })
  job:start()

  if no_sync then
    return job
  end

  job:wait(CHECK_TIMEOUT)
  return conflict_cache[filename] or NIL_CACHE
end

--[[
TODO:
- on M.update() use nvim_buf_attach() to get line changes with nvim_buf_lines_event()
- nvim_buf_detach() on M.reset()
- use nvim_win_get_cursor() to get the cursor position and check if it is within conflicts
]]

function M.conflict_lines(bufnr)
  bufnr = bufnr or 0
  local filename = buf_filename(bufnr)

  return check_for_conflicts(filename)
end

function M.has_conflict(bufnr)
  bufnr = bufnr or 0
  return M.conflict_lines(bufnr) ~= NIL_CACHE
end

function M.has_conflict_at_cursor(bufnr)
  bufnr = bufnr or 0
  return false
end

function M.reset()
  local filename = buf_filename(0)
  conflict_cache[filename] = nil
end

function M.update()
  check_for_conflicts(buf_filename(0), true)
end

function M.setup()
  vim.cmd('augroup git-conflict-resolve | autocmd! | augroup END')

  vim.cmd[[autocmd git-conflict-resolve FocusGained,BufEnter,CursorMoved,CursorMovedI * lua require("gcr").update()]]
  vim.cmd[[autocmd git-conflict-resolve FocusLost,BufUnload,BufLeave * lua require("gcr").reset()]]

  M.update()
end

return M
