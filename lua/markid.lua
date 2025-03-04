local ts = require("nvim-treesitter")
local parsers = require("nvim-treesitter.parsers")
local configs = require("nvim-treesitter.configs")

local namespace = vim.api.nvim_create_namespace("markid")

-- Global table to store names of created highlight groups
local hl_group_of_identifier = {}

local string_to_int = function(str)
    if str == nil then
        return 0
    end
    local int = 0
    for i = 1, #str do
        local c = str:sub(i, i)
        int = int + string.byte(c)
    end
    return int
end


local M = {}

M.colors = {
    dark = { "#619e9d", "#9E6162", "#81A35C", "#7E5CA3", "#9E9261", "#616D9E", "#97687B", "#689784", "#999C63", "#66639C" },
    bright = {"#f5c0c0", "#f5d3c0", "#f5eac0", "#dff5c0", "#c0f5c8", "#c0f5f1", "#c0dbf5", "#ccc0f5", "#f2c0f5", "#d8e4bc" },
    medium = { "#c99d9d", "#c9a99d", "#c9b79d", "#c9c39d", "#bdc99d", "#a9c99d", "#9dc9b6", "#9dc2c9", "#9da9c9", "#b29dc9" }
}

M.queries = {
    default = "(identifier) @markid",
    javascript = [[
          (identifier) @markid
          (property_identifier) @markid
          (shorthand_property_identifier_pattern) @markid
          (shorthand_property_identifier) @markid
        ]]
}
M.queries.typescript = M.queries.javascript

function M.init()
    ts.define_modules {
        markid = {
            module_path = "markid",
            attach = function(bufnr, lang)
                local config = configs.get_module("markid")

                local query = vim.treesitter.query.get(lang, 'markid')
                if query == nil or query == '' then
                  query = vim.treesitter.query.parse(lang, config.queries[lang] or config.queries["default"])
                end
                local parser = parsers.get_parser(bufnr, lang)
                local tree = parser:parse()[1]
                local root = tree:root()

                local highlight_tree = function(root_tree, cap_start, cap_end)
                    if not vim.api.nvim_buf_is_loaded(bufnr) then
                      return
                    end
                    vim.api.nvim_buf_clear_namespace(bufnr, namespace, cap_start, cap_end)
                    for id, node in query:iter_captures(root_tree, bufnr, cap_start, cap_end) do
                        local name = query.captures[id]
                        if name == "markid" then
                            local text = vim.treesitter.get_node_text(node, bufnr)
                            if text ~= nil then
                                if hl_group_of_identifier[text] == nil then
                                    -- semi random: Allows to have stable global colors for the same name
                                    local colors_count = 0
                                    if not config.colors then
                                      while vim.fn.hlexists('markid' .. colors_count + 1) == 1 do
                                        colors_count = colors_count + 1
                                      end
                                    else
                                      colors_count = #config.colors
                                    end
                                    if colors_count == 0 then
                                      return
                                    end
                                    local idx = (string_to_int(text) % colors_count) + 1
                                    local group_name = "markid" .. idx
                                    if config.colors then
                                      vim.api.nvim_set_hl(0, group_name, { default = true, fg = config.colors[idx] })
                                    end
                                    hl_group_of_identifier[text] = group_name
                                end
                                local start_row, start_col, end_row, end_col = node:range()
                                local range_start = {start_row, start_col}
                                local range_end = {end_row, end_col}
                                vim.highlight.range(
                                    bufnr,
                                    namespace,
                                    hl_group_of_identifier[text],
                                    range_start,
                                    range_end
                                )
                            end
                        end
                    end
                end

                highlight_tree(root, 0, -1)
                parser:register_cbs(
                    {
                        on_changedtree = function(changes, tree)
                            vim.schedule(function ()
                                if vim.api.nvim_buf_is_valid(bufnr) then
                                    highlight_tree(tree:root(), 0, -1) -- can be made more efficient, but for plain identifier changes, `changes` is empty
                                end
                            end)
                        end
                    }
                )
            end,
            detach = function(bufnr)
                if vim.api.nvim_buf_is_valid(bufnr) then
                  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
                end
            end,
            is_supported = function(lang)
                local queries = configs.get_module("markid").queries
                return pcall(vim.treesitter.query.parse, lang, queries[lang] or queries["default"])
            end,
            colors = M.colors.medium,
            queries = M.queries
        }
    }
end

return M
