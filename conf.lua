vim.keymap.set("n", "<leader>rl", function()
    vim.cmd("Lazy reload banana.nvim")
    vim.cmd("Lazy reload when2meet.nvim")
end, { desc = "Reload" })

vim.keymap.set("n", "<leader>rb", function()
    vim.cmd("BananaSo")
end, { desc = "Run Nml" })
