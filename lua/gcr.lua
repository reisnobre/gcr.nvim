local Job = require'plenary.job'
local Path = require "plenary.path"
local api = vim.api
local split = vim.split
local startswith = vim.startswith
local buf_filename = api.nvim_buf_get_name
local get_cursor = api.nvim_win_get_cursor
local set_cursor = api.nvim_win_set_cursor
local buf_get_lines = api.nvim_buf_get_lines

local DEBUG = false

-- Used for debug logging
local function log() end
if DEBUG then
  DEBUG = {}
  log = function(...)
    DEBUG[#DEBUG + 1] = table.concat({ string.format(...) }, " ")
  end
end


local CHECK_TIMEOUT = 500
-- nil is a hit miss, this is an empty cache hit that can be used as check by ref
local NIL_CACHE = {}

local M = {}
M.debug = DEBUG

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
      table.insert(results, tonumber(parts[2]))
    end
  end
  if #results == 0 then
    return NIL_CACHE
  end

  return results
end

local function is_marker_begin(line)
  return startswith(line, '<<<<<<< ')
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

local function jump_to_conflict(backward, wrap)
  local cur_row = get_cursor(0)[1]
  local lines = M.conflict_lines()
  local first = nil
  local previous = nil
  local last = nil
  for _, line_nr in ipairs(lines) do
    local line = buf_get_lines(0, line_nr - 1, line_nr, false)[1]
    local starts_conflict = is_marker_begin(line)
    if starts_conflict then
      if wrap then
        if first == nil then
          first = line_nr
        end

        last = line_nr
      end

      if backward and line_nr < cur_row then
        previous = line_nr
      end

      -- go to previous
      if line_nr >= cur_row and previous ~= nil then
        set_cursor(0, {previous, 0})
        return
      end

      -- go to next
      if not backward and line_nr > cur_row then
        set_cursor(0, {line_nr, 0})
        return
      end
    end
  end

  -- since we scanned all lines, we can wrap
  if wrap and first then
    -- wrap last to first
    if not backward then
      set_cursor(0, {first, 0})
      return
    end

    -- wrap first to last
    if backward and cur_row <= first then
        set_cursor(0, {last, 0})
    end
  end
end

function M.next_conflict(wrap)
  jump_to_conflict(false, wrap)
end

function M.prev_conflict(wrap)
  jump_to_conflict(true, wrap)
end

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
