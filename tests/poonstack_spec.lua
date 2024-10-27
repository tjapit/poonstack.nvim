describe("poonstack", function()
	it("can be required", function()
		require("poonstack")
	end)

	it("can push a single item", function()
		local exp_item = {
			context = { row = 0, col = 0 },
			value = "README.md",
		}
		local expected = { exp_item }

		local poonstack = require("poonstack")
		poonstack.push(expected) -- -> poonstack
		poonstack.load() -- poonstack -> harpoon

		local actual = require("harpoon"):list().items
		assert.are.same(expected, actual, "should have a single item: README.md")
	end)

	it("can push multiple items", function()
		local exp_item1 = {
			context = { row = 0, col = 0 },
			value = "README.md",
		}
		local exp_item2 = {
			context = { row = 0, col = 0 },
			value = ".gitignore",
		}
		local expected = { exp_item1, exp_item2 }

		local poonstack = require("poonstack")
		poonstack.push(expected) -- -> poonstack
		poonstack.load() -- poonstack -> harpoon

		local actual = require("harpoon"):list().items
		assert.are.same(expected, actual, "should have a two items: README.md and .gitignore")
	end)
end)