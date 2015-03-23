--- Marquee widget for scrolling text.
--
-- @todo skin?

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

-- Modules --
local M = {}

--[[
-- --
local MarqueeText

-- --
local ScrollParams, Scrolling = { iterations = -1 }

--
local function ScrollText ()
	if Scrolling then
		transition.cancel(Scrolling)

		Scrolling = nil	
	end

	if #MarqueeText.text > 0 then
		local w = MarqueeText.width + 15

		MarqueeText.x, ScrollParams.x, ScrollParams.time = display.contentWidth, -w, w * 12

		Scrolling = transition.to(MarqueeText, ScrollParams)
	end
end
]]

--[[

		MarqueeText.text = text and text .. " " or ""

		ScrollText()
]]

--[[
	MarqueeText = display.newText(self.view, "", 0, 0, native.systemFontBold, 28)

]]

--[[
	local marquee = display.newRoundedRect(self.view, 0, 0, display.contentWidth - 4, 50, 5)

	marquee.anchorX, marquee.x = 0, 2
	marquee.anchorY, marquee.y = 1, display.contentHeight - 2
	marquee.strokeWidth = 3

	marquee:setFillColor(0, 0)
	marquee:setStrokeColor(1, 0, 0)

	MarqueeText.anchorX, MarqueeText.anchorY, MarqueeText.y = 0, 1, marquee.y
]]

-- Export the module.
return M