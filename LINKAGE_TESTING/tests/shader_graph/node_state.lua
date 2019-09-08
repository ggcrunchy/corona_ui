--- Various state related to nodes.

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
local assert = assert
local type = type

-- Modules --
local nc = require("corona_ui.patterns.node_cluster")

-- Cached module references --
local _ResolvedType_
local _WildcardType_

-- Exports --
local M = {}

--
--
--

local HardToWildcard = {}

--- DOCME
function M.AddHardToWildcardEntries (entries)
    assert(type(entries) == "table", "Entries table expected")

    local wildcard_type = assert(entries.wildcard_type, "Expected wildcard type")

    for i = 1, #entries do
        assert(not HardToWildcard[entries[i]], "Entry already present in hard -> wildcard map")
    end

    for i = 1, #entries do
        HardToWildcard[entries[i]] = wildcard_type
    end
end

local Connected = {}

--- DOCME
function M.BreakOldConnection (node)
	-- n.b. at moment all nodes are exclusive
	local _, n = nc.GetConnectedObjects(node, Connected)

	for i = 1, n do -- n = 0 or 1
		nc.DisconnectObjects(node, Connected[i])

		Connected[i] = false
	end
end

--- DOCME
function M.Classify (x, y)
	if y.hard_type then -- either node (or both) might have hard type; in this case, we can
						-- streamline some of the next steps by making sure "x" does
		x, y = y, x
	end

	if not y.hard_type then -- if both were hard, we have nothing left to do
		local hard_type = x.hard_type
	
		if not hard_type then
			return "neither_hard"
		elseif hard_type ~= y.nonresolving_hard_type then -- at the moment, only the "hard" case matters
			return "hard", x, y
		end
	end
end

--- DOCME
function M.HardType (node)
    return node.hard_type
end

--- DOCME
function M.QueryRule (node, other, compatible)
    local hard_type, other_resolved = node.hard_type, _ResolvedType_(other)

    if hard_type then
        if other_resolved == nil then
            return HardToWildcard[hard_type] == _WildcardType_(other)
        else
            return hard_type == other_resolved
        end
    else
        local nonresolving_hard_type = node.nonresolving_hard_type

        if nonresolving_hard_type and other_resolved == nonresolving_hard_type then
            return true
        elseif compatible then
            local node_resolved = _ResolvedType_(node)

            if node_resolved == other_resolved then -- both resolved or wild
                return true
            elseif node_resolved == nil then
                return "resolve", other_resolved
            else
                return other_resolved == nil -- give other chance to resolve
            end
        end
    end
end

--- DOCME
function M.ResolvedType (node)
	return node.hard_type or node.parent.resolved_type
end

--- DOCME
function M.ScourConnectedNodes (parent, func, arg)
	for i = 1, parent.numChildren do
		local _, n = nc.GetConnectedObjects(parent[i], Connected)

		for j = 1, n do
			local cnode = Connected[j]

			Connected[j] = false

			func(cnode, arg)
		end
	end
end

--- DOCME
function M.SetHardType (node, htype)
    node.hard_type = htype
end

--- DOCME
function M.SetNonResolvingHardType (node, htype)
    node.nonresolving_hard_type = htype
    node.parent.wildcard_type = HardToWildcard[htype]
end

--- DOCME
function M.SetResolvedType (parent, rtype)
    parent.resolved_type = rtype
end

--- DOCME
function M.SetWildcardType (parent, wtype)
    parent.wildcard_type = wtype
end

--- DOCME
function M.WildcardType (node)
	return node.parent.wildcard_type
end

--- DOCME
function M.WilcardOrHardType (node)
	local hard_type = node.hard_type

	if hard_type then
		return HardToWildcard[hard_type]
	else
		return _WildcardType_(node)
	end
end

_ResolvedType_ = M.ResolvedType
_WildcardType_ = M.WildcardType

return M