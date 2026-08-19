local state = require("config.floating.state")

local M = {}

local MIN_WIDTH = 12
local MIN_HEIGHT = 4

local function leaf(id)
    return { pane = id }
end

local function find(node, pane_id, parent)
    if not node then
        return nil
    end
    if node.pane == pane_id then
        return node, parent
    end
    local found, owner = find(node.first, pane_id, node)
    if found then
        return found, owner
    end
    return find(node.second, pane_id, node)
end

local function replace(node, pane_id, replacement)
    if node.pane == pane_id then
        return replacement
    end
    if node.first then
        node.first = replace(node.first, pane_id, replacement)
        node.second = replace(node.second, pane_id, replacement)
    end
    return node
end

local function remove(node, pane_id)
    if not node or node.pane == pane_id then
        return nil
    end
    if not node.first then
        return node
    end
    node.first = remove(node.first, pane_id)
    node.second = remove(node.second, pane_id)
    if not node.first then return node.second end
    if not node.second then return node.first end
    return node
end

local function rectangles(node, rect, result)
    if node.pane then
        result[node.pane] = rect
        return
    end
    local ratio = node.ratio or 0.5
    if node.direction == "vertical" then
        local available = rect.width - 2
        local first = math.floor(available * ratio)
        first = math.max(MIN_WIDTH, math.min(available - MIN_WIDTH, first))
        rectangles(node.first, { row = rect.row, col = rect.col, width = first, height = rect.height }, result)
        rectangles(node.second, { row = rect.row, col = rect.col + first + 2, width = available - first, height = rect.height }, result)
    else
        local available = rect.height - 2
        local first = math.floor(available * ratio)
        first = math.max(MIN_HEIGHT, math.min(available - MIN_HEIGHT, first))
        rectangles(node.first, { row = rect.row, col = rect.col, width = rect.width, height = first }, result)
        rectangles(node.second, { row = rect.row + first + 2, col = rect.col, width = rect.width, height = available - first }, result)
    end
end

function M.ensure(item)
    item.panes = item.panes or { A = { id = "A", buf = item.buf, win = item.win, view = item.view, cursor = item.cursor } }
    item.layout = item.layout or leaf("A")
    for pane_id, pane in pairs(item.panes) do
        if state.valid_window(pane.win) and state.valid_buffer(pane.buf) then
            state.mark_pane(pane.win, pane.buf, state.window_slot_id(pane.win), pane_id)
        end
    end
    return item
end

function M.split(item, pane_id, direction, new_id)
    M.ensure(item)
    item.layout = replace(item.layout, pane_id, {
        direction = direction,
        ratio = 0.5,
        first = leaf(pane_id),
        second = leaf(new_id),
    })
end

function M.remove(item, pane_id)
    M.ensure(item)
    item.layout = remove(item.layout, pane_id)
end

function M.compact(item)
    M.ensure(item)
    local ordered = {}
    local function collect(node)
        if node.pane then
            table.insert(ordered, node.pane)
            return
        end
        collect(node.first)
        collect(node.second)
    end
    collect(item.layout)

    local renamed = {}
    local mapping = {}
    for index, old_id in ipairs(ordered) do
        local new_id = string.char(string.byte("A") + index - 1)
        local pane = item.panes[old_id]
        if pane then
            pane.id = new_id
            renamed[new_id] = pane
            mapping[old_id] = new_id
        end
    end
    local function rename_tree(node)
        if node.pane then
            node.pane = mapping[node.pane] or node.pane
            return
        end
        rename_tree(node.first)
        rename_tree(node.second)
    end
    rename_tree(item.layout)
    item.panes = renamed
    return mapping
end

function M.rectangles(item, rect)
    M.ensure(item)
    local result = {}
    rectangles(item.layout, rect, result)
    return result
end

function M.can_split(item, pane_id, direction, rect)
    local current = M.rectangles(item, rect)[pane_id]
    if not current then return false end
    if direction == "vertical" then return current.width >= MIN_WIDTH * 2 + 2 end
    return current.height >= MIN_HEIGHT * 2 + 2
end

local function center(rect)
    return rect.col + rect.width / 2, rect.row + rect.height / 2
end

function M.neighbor(item, pane_id, direction, rect)
    local all = M.rectangles(item, rect)
    local current = all[pane_id]
    if not current then return nil end
    local cx, cy = center(current)
    local best, distance
    for id, candidate in pairs(all) do
        if id ~= pane_id then
            local x, y = center(candidate)
            local valid = (direction == "left" and x < cx) or (direction == "right" and x > cx)
                or (direction == "up" and y < cy) or (direction == "down" and y > cy)
            if valid then
                local primary = (direction == "left" or direction == "right") and math.abs(x - cx) or math.abs(y - cy)
                local secondary = (direction == "left" or direction == "right") and math.abs(y - cy) or math.abs(x - cx)
                local score = primary * 1000 + secondary
                if not distance or score < distance then best, distance = id, score end
            end
        end
    end
    return best
end

function M.resize(item, pane_id, direction, delta, rect)
    M.ensure(item)
    local wanted = (direction == "left" or direction == "right") and "vertical" or "horizontal"
    local function ancestors(root, target, stack)
        if root.pane == target then return stack end
        if root.first then
            local next_stack = vim.list_extend(vim.deepcopy(stack), { root })
            return ancestors(root.first, target, next_stack) or ancestors(root.second, target, next_stack)
        end
    end
    local list = ancestors(item.layout, pane_id, {}) or {}
    for index = #list, 1, -1 do
        local parent = list[index]
        if parent.direction == wanted then
            local total = wanted == "vertical" and rect.width or rect.height
            local signed = delta / math.max(total, 1)
            if find(parent.first, pane_id) == nil then signed = -signed end
            parent.ratio = math.max(0.1, math.min(0.9, (parent.ratio or 0.5) + signed))
            return true
        end
    end
    return false
end

return M
