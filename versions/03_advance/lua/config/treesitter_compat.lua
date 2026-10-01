local M = {}

-- The master branch expects individual captures. Neovim 0.12 removed
-- add_predicate/add_directive's all=false conversion to that format.
function M.setup()
    if vim.fn.has("nvim-0.12") == 0
        or package.loaded["nvim-treesitter.query_predicates"] then
        return
    end

    local query = vim.treesitter.query
    local add_predicate = query.add_predicate
    local add_directive = query.add_directive

    local function legacy_registration(register)
        return function(name, handler, opts)
            if type(opts) == "table" and opts.all == false then
                local original = handler
                handler = function(match, ...)
                    local captures = {}
                    for id, nodes in pairs(match) do
                        captures[id] = type(nodes) == "table" and nodes[1] or nodes
                    end
                    return original(captures, ...)
                end
            end
            return register(name, handler, opts)
        end
    end

    -- Adapt only the legacy plugin's registrations, then restore the API.
    query.add_predicate = legacy_registration(add_predicate)
    query.add_directive = legacy_registration(add_directive)
    local ok, err = pcall(require, "nvim-treesitter.query_predicates")
    query.add_predicate = add_predicate
    query.add_directive = add_directive
    if not ok then
        error(err)
    end
end

return M
