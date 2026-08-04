local cleanup = require("config.buffers.window_cleanup")
local ops = require("config.buffers.window_ops")
local tabs = require("config.buffers.window_tabs")
local visibility = require("config.buffers.window_visibility")

local M = {}

M.visible_for_buffer = visibility.visible_for_buffer
M.all_visible_for_buffer = visibility.all_visible_for_buffer
M.all_visible_count = visibility.all_visible_count
M.current_visible_for_buffer = visibility.current_visible_for_buffer
M.any_visible_for_buffer = visibility.any_visible_for_buffer
M.first_selectable_for_buffer = visibility.first_selectable_for_buffer

M.fallback_for_cleared_window = cleanup.fallback_for_cleared_window
M.clear_showing_buffer = cleanup.clear_showing_buffer
M.restore_after_failed_delete = cleanup.restore_after_failed_delete
M.clear_listed_except = cleanup.clear_listed_except
M.restore_cleared = cleanup.restore_cleared

M.restore_tabpage = tabs.restore_tabpage
M.pick_tab_for_window = tabs.pick_tab_for_window

M.move_buffer_to_window = ops.move_buffer_to_window
M.move_current_to_window = ops.move_current_to_window
M.open_current_in_window = ops.open_current_in_window
M.open_buffer_in_window = ops.open_buffer_in_window
M.open_buffer_in_split = ops.open_buffer_in_split

return M
