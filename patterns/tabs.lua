--- Some useful UI patterns based around tab bars.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local ipairs = ipairs
local pairs = pairs

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

-- --
local function Name (what, bar)
	return "corona_ui/assets/tab" .. (bar and "Bar_tab" or "") .. what .. ".png"
end

--- Creates a tab bar.
-- @pgroup group Group to which tab bar will be inserted.
-- @array buttons Tab buttons, cf. `widget.newTabBar`.
-- @ptable options Argument to `widget.newTabBar` (**buttons** is overridden).
-- @treturn DisplayObject Tab bar object.
function M.TabBar (group, buttons, options)
	for _, button in ipairs(buttons) do
		button.overFile, button.defaultFile = Name("Icon-down"), Name("Icon")
		button.width, button.height, button.size = 32, 32, 14
	end

	local topts = {}

	for k, v in pairs(options) do
		topts[k] = v
	end

	topts.buttons = buttons
	topts.backgroundFile = Name("bar")
	topts.tabSelectedLeftFile = Name("SelectedLeft", true)
	topts.tabSelectedMiddleFile = Name("SelectedMiddle", true)
	topts.tabSelectedRightFile = Name("SelectedRight", true)
	topts.tabSelectedFrameWidth = 20
	topts.tabSelectedFrameHeight = 52

	local tbar = widget.newTabBar(topts)

	group:insert(tbar)

	return tbar
end

--- HACK!
-- TODO: Remove this if fixed
function M.TabsHack (group, tabs, n, x, y, w, h)
	local is_func = type(x) == "function"
	local ex = is_func and x() or x
	local rect = display.newRect(group, 0, 0, w or tabs.width, h or tabs.height)

	if not ex then
		rect.x, rect.y = tabs.x, tabs.y
	else
		rect.x, rect.y = ex, y or 0

		rect:translate(rect.width / 2, rect.height / 2)
	end

	rect:addEventListener("touch", function(event)
		local bounds = event.target.contentBounds
		local index = math.min(require("tektite_core.array.index").FitToSlot(event.x, bounds.xMin, (bounds.xMax - bounds.xMin) / n), n)

		if is_func then
			local _, extra = x()

			index = index + extra
		end

		tabs:setSelected(index, true)

		return true
	end)

	rect.isHitTestable, rect.isVisible = true, false

	return rect
end

-- Export the module.
return M