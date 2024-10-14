local api = vim.api
local fn = vim.fn

local M = {}
local NS_ID = api.nvim_create_namespace('VisualWhitespace')
local CFG = {
  highlight = { link = "Visual" },
  space_char = '·',
  tab_char = '→',
  nl_char = '↲',
  cr_char = '←'
}
local CHAR_LOOKUP


local function get_normalized_pos(s_pos, e_pos, mode)
  local pos_list = fn.getregionpos(s_pos, e_pos, { type = mode, eol = true })

  s_pos = { pos_list[1][1][2], pos_list[1][1][3] }
  e_pos = { pos_list[#pos_list][2][2], pos_list[#pos_list][2][3] }

  return s_pos, e_pos
end

local function get_marks(s_pos, e_pos, mode)
  local ff = vim.bo.fileformat
  local nl_str = ff == 'unix' and '\n' or ff == 'mac' and '\r' or '\r\n'

  local srow, scol = s_pos[1], s_pos[2]
  local erow, ecol = e_pos[1], e_pos[2]

  local text = api.nvim_buf_get_lines(0, srow - 1, erow, true)

  local line_text, line_len, adjusted_scol, adjusted_ecol, match_char
  local ws_marks = {}

  for cur_row = srow, erow do
    -- gets the physical line, not the display line
    line_text = table.concat { text[cur_row - srow + 1], nl_str }
    line_len = #line_text

    -- adjust start_col and end_col for partial line selections
    if mode == 'v' then
      adjusted_scol = (cur_row == srow) and scol or 1
      adjusted_ecol = (cur_row == erow) and ecol or line_len

      --[[
        There are four ranges to manage:
          1. start to end
          2. start to middle
          3. middle to middle
          4. middle to end

        In cases 2 and 3, we can get a substring to the
        end column which the start column is always inside of, e.g.
        1 to ecol, so that we can continue using string.find().
      ]]
      if (adjusted_ecol ~= line_len) then
        line_text = line_text:sub(1, adjusted_ecol)
      end
    else
      adjusted_scol = scol
    end

    -- process columns of current line
    repeat
      adjusted_scol, _, match_char = string.find(line_text, "([ \t\r\n])", adjusted_scol)

      if adjusted_scol then
        if ff == 'dos' and line_len == adjusted_scol then
          table.insert(ws_marks, { cur_row, 0, CHAR_LOOKUP[match_char], "eol" })
        else
          table.insert(ws_marks, { cur_row, adjusted_scol, CHAR_LOOKUP[match_char], "overlay" })
        end

        adjusted_scol = adjusted_scol + 1
      end
    until not adjusted_scol
  end

  return ws_marks
end

local function apply_marks(mark_table)
  for _, mark_data in ipairs(mark_table) do
    api.nvim_buf_set_extmark(0, NS_ID, mark_data[1] - 1, mark_data[2] - 1, {
      virt_text = { { mark_data[3], 'VisualNonText' } },
      virt_text_pos = mark_data[4],
    })
  end
end

M.clear_ws_hl = function()
  api.nvim_buf_clear_namespace(0, NS_ID, 0, -1)
end

M.highlight_ws = function()
  local cur_mode = fn.mode()

  if cur_mode ~= 'v' and cur_mode ~= 'V' then
    return
  end

  local s_pos = fn.getpos('v')
  local e_pos = fn.getpos('.')

  s_pos, e_pos = get_normalized_pos(s_pos, e_pos, cur_mode)

  M.clear_ws_hl()

  local marks = get_marks(s_pos, e_pos, cur_mode)

  apply_marks(marks)
end

M.setup = function(user_cfg)
  CFG = vim.tbl_extend('force', CFG, user_cfg or {})
  CHAR_LOOKUP = {
    [' '] = CFG['space_char'],
    ['\t'] = CFG['tab_char'],
    ['\n'] = CFG['nl_char'],
    ['\r'] = CFG['cr_char']
  }

  api.nvim_set_hl(0, 'VisualNonText', CFG['highlight'])
end


return M
