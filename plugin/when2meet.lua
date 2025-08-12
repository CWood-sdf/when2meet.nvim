---@module 'banana.instance'

---@type Banana.Instance?
local ui = nil
vim.api.nvim_create_user_command("When2Meet", function()
    if ui == nil then
        ui = require("banana.instance").newInstance("when2meet", "")
    end
    ui:open()
end, {})
