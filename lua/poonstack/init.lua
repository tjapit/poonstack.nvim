local utils = require("poonstack.utils")
local harpoon = require("harpoon")
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")

local M = {}

M.config = {
	cwd = vim.fn.getcwd(),
	branch = vim.fn.system("git branch --show-current"):trim(),
	poonstack_dir = os.getenv("HOME") .. "/.local/state/nvim/poonstack",
}

M._poonstack = {}

M.setup = function(config)
	M.config = vim.tbl_deep_extend("force", M.config, config or {})

	local err = M._create_poonstack_dir()
	if err then
		vim.notify(err, vim.log.levels.ERROR)
	end

	err = M._create_poonstack_file()
	if err then
		vim.notify(err, vim.log.levels.ERROR)
	end

	vim.api.nvim_create_user_command("PoonstackGitCheckout", function()
		require("telescope.builtin").git_branches({
			attach_mappings = function(_, map)
				map("i", "<CR>", M.poonstack_git_checkout)
				map("n", "<CR>", M.poonstack_git_checkout)
				return true
			end,
		})
	end, {})

	local poonstack_augroup = vim.api.nvim_create_augroup("Poonstack", {})
	vim.api.nvim_create_autocmd({ "BufWritePost", "BufLeave", "FocusLost" }, {
		group = poonstack_augroup,
		callback = function()
			M.push()
			M.write()
		end,
	}) -- write to poonstack file after saving buffer to file

	harpoon:list():clear() -- override harpoon persistence
	M.read() -- file > poonstack
	M.pop() -- poonstack > harpoon
end

---Override telescope.builtin.git_branches() with
---@param prompt_bufnr any
M.poonstack_git_checkout = function(prompt_bufnr)
	local selection = actions_state.get_selected_entry()
	if selection then
		local branch = selection.value

		actions.git_checkout(prompt_bufnr)

		M.on_switch_branch(branch)
	end
end

---Does the book-keeping when switching branches
---
---Pushes current harpoon > poonstack, writes it to the poonstack file, changes
---the current branch, clears harpoon, and pops poonstack > harpoon for current
---branch
---@param branch string name of the branch to check out
M.on_switch_branch = function(branch)
	M.push()
	M.write()
	M.config.branch = branch
	harpoon:list():clear()
	M.pop()
end

M._create_poonstack_dir = function()
	-- 1 if path is directory
	-- 0 if path not diirectory or not exists
	-- nil on error
	if vim.fn.isdirectory(M.config.poonstack_dir) then
		return
	end

	-- returns 1 if created, 0 if already exists
	-- nil if error during creation
	if not vim.fn.mkdir(M.config.poonstack_dir) then
		return -- failed to create directory
	end
end

---Creates poonstack file and assigns the path and filename to M.config
---@return nil|string error nil on success, error message on error
M._create_poonstack_file = function()
	-- if not git tracked, don't create file
	if not utils.istracked() then
		return
	end

	M.config.poonstack_file = M.get_poonstack_file()
	M.config.poonstack_filepath = M.get_poonstack_filepath()

	if vim.fn.filereadable(M.config.poonstack_filepath) == 1 then
		return -- don't create file if already exists
	end

	if vim.fn.writefile({}, M.config.poonstack_filepath) == -1 then
		return "error creating poonstack file" -- error when creating file
	end
end

---Returns the filepath that stores the harpoon list for the current workking
---directory.
---
---It replaces all the slashes (/) with percents (%) and the ends with the
---project directory name with a .json extension.
---
---@return string poonstack_file the poonstack file that stores harpoon list
M.get_poonstack_file = function()
	return M.config.cwd:gsub("/", "%%") .. ".json"
end

---Returns the absolute path to the poonstack file.
---
---@return string poonstack_filepath poonstack absolute path
M.get_poonstack_filepath = function()
	return M.config.poonstack_dir .. "/" .. M.get_poonstack_file()
end

---Writes the poonstack to the given file.
---
---Converts the poonstack into json before writing it to the file.
---
---@return nil|string result nil on success, error message on error
M.write = function()
	-- write from M._poonstack to file
	local poonstack_json = vim.fn.json_encode(M._poonstack)
	return vim.fn.writefile({ poonstack_json }, M.config.poonstack_filepath)
end

---Reads from the poonstack file and loads it to the poonstack
M.read = function()
	if vim.fn.filereadable(M.config.poonstack_filepath) == 0 then
		return "file does not exist/not readable"
	end

	local poonstack_json = vim.fn.readfile(M.config.poonstack_filepath)
	if poonstack_json == {} then
		return "empty poonstack file"
	end

	if #poonstack_json == 0 then
		return
	end

	M._poonstack = vim.fn.json_decode(poonstack_json)
end

---Pops the poon of the current branch from poonstack > harpoon
---
---@return table|nil poon harpoon list of current branch, nil if not found
M.pop = function()
	local poon = M._poonstack[M.config.branch]
	if not poon then
		return
	end

	for _, poonitem in ipairs(poon) do
		harpoon:list():add(poonitem)
	end

	return poon
end

---Pushes the current branch's harpoon > poonstack
--
M.push = function()
	local poon = harpoon:list().items
	M._poonstack[M.config.branch] = poon
end

M._clear = function()
	M._poonstack = {}
end

return M
