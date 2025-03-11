local P = {}

P.opts = {
	---@type vim.api.keyset.win_config
	window = {
		relative = 'cursor',
		row = 1,
		col = 1,
		width = 50,
		height = 10,
		anchor = 'NW',
		style = 'minimal',
		border = 'rounded',
	},
}

---@param config vim.api.keyset.win_config
P.create_floating_win = function(config)
	local bufnr = vim.api.nvim_create_buf(false, true)

	local winnr = vim.api.nvim_open_win(bufnr, true, config)

	return { buf = bufnr, win = winnr }
end

P.search_emojis = function(query)
	query = query:lower()

	local results = {}
	local emojis = require('emojis.data.emoji-list').emojis

	if query == '' then
		for _, emoji in ipairs(emojis) do
			table.insert(results, emoji.value)
		end

		return results
	end

	for _, emoji in ipairs(emojis) do
		if
			emoji.name:lower():find(query)
			or emoji.category:lower():find(query)
			or emoji.description:lower():find(query)
		then
			table.insert(results, emoji.value)
		end
	end

	return results
end

P.open_win = function()
	local windows = {
		header = {
			relative = 'cursor',
			row = 1,
			col = 1,
			width = 40,
			height = 1,
			anchor = 'NW',
			style = 'minimal',
			border = { '┌', '─', '┐', '│', '┤', '─', '├', '│' },
		},
		body = {
			relative = 'cursor',
			row = 1,
			col = -1,
			width = 40,
			height = 10,
			anchor = 'NW',
			style = 'minimal',
			border = { '├', '─', '┤', '│', '┘', '─', '└', '│' },
		},
	}

	local header = P.create_floating_win(windows.header)
	local body = P.create_floating_win(windows.body)

	vim.api.nvim_set_current_win(header.win)

	vim.api.nvim_set_option_value('modifiable', false, { buf = body.buf })

	vim.api.nvim_create_autocmd('WinClosed', {
		buffer = body.buf,
		callback = function()
			P.close_win(header.win, header.buf)
		end,
	})

	vim.api.nvim_create_autocmd('WinClosed', {
		buffer = header.buf,
		callback = function()
			P.close_win(body.win, body.buf)
		end,
	})

	P.set_close_keys({ 'q', '<esc>' }, header.win, header.buf)
	P.set_close_keys({ 'q', '<esc>' }, body.win, body.buf)

	vim.keymap.set('n', '<C-j>', function()
		vim.api.nvim_set_current_win(body.win)
	end, { buffer = header.buf })

	vim.keymap.set('n', '<C-j>', function()
		vim.api.nvim_set_current_win(header.win)
	end, { buffer = body.buf })

	vim.keymap.set('n', '<C-k>', function()
		vim.api.nvim_set_current_win(header.win)
	end, { buffer = body.buf })

	vim.keymap.set('n', '<C-k>', function()
		vim.api.nvim_set_current_win(body.win)
	end, { buffer = header.buf })

	vim.keymap.set('n', 'l', 'w', { buffer = body.buf, noremap = true })
	vim.keymap.set('n', 'h', 'b', { buffer = body.buf, noremap = true })

	local results = P.search_emojis('')
	P.set_results(results, body)

	local first_emoji = results[1] or nil

	vim.keymap.set('n', '<cr>', function()
		local char = P.get_char_at_cursor()
		P.close_win(body.win, body.buf)
		vim.api.nvim_put({ char }, 'c', true, true)
	end, { buffer = body.buf })

	vim.keymap.set('n', '<cr>', function()
		P.close_win(header.win, header.buf)
		vim.api.nvim_put({ first_emoji }, 'c', true, true)
	end, { buffer = header.buf })

	vim.api.nvim_create_autocmd('TextChangedI', {
		buffer = header.buf,
		callback = function()
			local value = vim.api.nvim_get_current_line()
			local emojis = P.search_emojis(value)
			first_emoji = emojis[1]

			P.set_results(emojis, body)
		end,
	})
end

P.format_columns = function(items, column_width, max_columns)
	local lines = {}
	local row = {}
	for i, item in ipairs(items) do
		-- Add padding to align columns
		table.insert(row, string.format('%-' .. column_width .. 's', item))

		-- Move to next row after reaching max_columns
		if #row == max_columns or i == #items then
			table.insert(lines, table.concat(row, ' '))
			row = {}
		end
	end
	return lines
end

P.set_results = function(results, body)
	vim.api.nvim_set_option_value('modifiable', true, { buf = body.buf })

	-- Format emojis into columns
	local column_width = 6
	local max_columns = 8
	local formatted_emojis = P.format_columns(results, column_width, max_columns)

	vim.api.nvim_buf_set_lines(body.buf, 1, -1, false, formatted_emojis)
	vim.api.nvim_set_option_value('modifiable', false, { buf = body.buf })
end

P.close_win = function(winnr, bufnr)
	pcall(vim.api.nvim_win_close, winnr, false)
	pcall(vim.api.nvim_buf_delete, bufnr)
end

P.get_char_at_cursor = function()
	return vim.fn.strcharpart(
		vim.fn.strpart(vim.fn.getline('.'), vim.fn.col('.') - 1),
		0,
		1
	)
end

P.set_close_keys = function(keys, winnr, bufnr)
	for _, key in ipairs(keys) do
		vim.keymap.set('n', key, function()
			P.close_win(winnr, bufnr)
		end, { buffer = bufnr })
	end
end

local M = {}

M.setup = function(opts)
	P.config = vim.tbl_deep_extend('force', P.opts, opts or {})
	vim.api.nvim_create_user_command('EmojiPicker', P.open_win, {})
end

return M
