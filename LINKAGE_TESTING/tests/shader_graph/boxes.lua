--- Shader graph box logic.

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
local error = error
local pairs = pairs

-- Modules --
local dfs = require("tests.shader_graph.dfs")
local nl = require("tests.shader_graph.node_layout")
local ns = require("tests.shader_graph.node_state")

-- Exports --
local M = {}

--
--
--

--
-- Connectedness search
--

local AdjacencyStack = {}

local Height = 0

local function Push (node)
	Height = Height + 1

	local aboxes = AdjacencyStack[Height] or {}

	AdjacencyStack[Height], aboxes.node = aboxes, node

	return aboxes
end

local function AuxAdjacentBoxesIter (aboxes, index)
	local box = aboxes[index + 1]

	if box then
		return index + 1, box
	else -- clean up when done
		for i = #aboxes, 1, -1 do
			aboxes[i] = nil
		end

		Height = Height - 1
	end
end

local function MakeAdjacencyIterator(gather)
	return function(_, node) -- TODO: node works as index EXCEPT with undo / redo
		local aboxes = Push(node)

		ns.VisitConnectedNodes(node.parent, gather, aboxes)

		aboxes.node = nil

		return AuxAdjacentBoxesIter, aboxes, 0
	end
end

local Opts = { top_level_iter = "root" }

local OnFoundHard

Opts.adjacency_iter = MakeAdjacencyIterator(function(neighbor, aboxes)
	local what = ns.Classify(neighbor, aboxes.node)

	if what == "hard" then
		OnFoundHard()
	elseif what == "neither_hard" then
		aboxes[#aboxes + 1] = neighbor
	end
end)

--
-- Connect / Resolve
--

local ConnectAlg = dfs.NewAlgorithm()

local ConnectionGen = 0

local ToResolve = {}

local function DoConnect (graph, node, adj_iter)
	ToResolve[node.parent] = ConnectionGen

	dfs.VisitAdjacentVertices_Once(ConnectAlg, DoConnect, graph, node, adj_iter)
end

local function MakeResolve (func)
	return function(parent, rtype)
		ns.SetResolvedType(parent, rtype)

		for i = 1, parent.numChildren do
			func(parent[i], rtype)
		end
	end
end

--
-- Disconnect / Decay
--

local DisconnectAlg = dfs.NewAlgorithm()

local DecayCandidates = { n = 0 }

local NoHardNodes

local function DoDisconnect (graph, node, adj_iter)
	if NoHardNodes then
		local n = DecayCandidates.n + 1

		DecayCandidates[n], DecayCandidates.n = node.parent, n

		dfs.VisitAdjacentVertices_Once(DisconnectAlg, DoDisconnect, graph, node, adj_iter)
	end
end

local function CanReachHardNode ()
	NoHardNodes = false
end

local ToDecay = {}

local function ExploreDisconnectedNode (node)
	DecayCandidates.n, NoHardNodes = 0, true

	dfs.VisitTopLevel(DisconnectAlg, DoDisconnect, node, Opts)

	for i = 1, NoHardNodes and DecayCandidates.n or 0 do
		ToDecay[DecayCandidates[i]] = ConnectionGen
	end

	for i = 1, DecayCandidates.n do
		DecayCandidates[i] = false
	end
end

local function MakeDecay (func)
	return function(parent)
		for i = 1, parent.numChildren do
			func(parent[i])
		end

		ns.SetResolvedType(parent, nil)
	end
end

--
-- Cluster logic
--

local function ApplyChanges (resize, list, func, arg)
	for box, gen in pairs(list) do
		if gen == ConnectionGen then
			func(box, arg)
            resize(box)
		end

        list[box] = nil
	end
end

local CycleCheckOpts = { top_level_iter = "root" }

local FromBox, FromSide, CycleFormed

CycleCheckOpts.adjacency_iter = MakeAdjacencyIterator(function(neighbor, aboxes)
	if neighbor.parent == FromBox then
		CycleFormed = true
	elseif nl.GetSide(neighbor) == FromSide then
		aboxes[#aboxes + 1] = neighbor
	end
end)

local CycleCheckAlg = dfs.NewAlgorithm()

local function DoCycleCheck (graph, node, adj_iter)
	if not CycleFormed then
		dfs.VisitAdjacentVertices_Once(CycleCheckAlg, DoCycleCheck, graph, node, adj_iter)
	end
end

local function FormsCycle (from, to)
	FromBox, FromSide, CycleFormed = from.parent, nl.GetSide(from)

	dfs.VisitTopLevel(CycleCheckAlg, DoCycleCheck, to, CycleCheckOpts)

	FromBox = nil

	return CycleFormed
end

local function CanConnect (a, b)
    local compatible = ns.WilcardOrHardType(a) == ns.WilcardOrHardType(b) -- e.g. restrict to vectors, matrices, etc.
    local how1, what1 = ns.QueryRule(a, b, compatible)
    local how2, what2 = ns.QueryRule(b, a, compatible)

    if how1 and how2 and not FormsCycle(a, b) then
        if how1 == "resolve" then
            a.resolve = what1
        elseif how2 == "resolve" then
            b.resolve = what2
        end

        return true
    end
end

local function EnumerateDecayCandidates (a, b)
    local ctype, x, y = ns.Classify(a, b)

    if ctype == "neither_hard" and ns.ResolvedType(a) then -- if a is resolved, so is b
        return 2, a, b
    else
        return ctype == "hard" and 1 or 0, x, y
    end
end

local function FindNodeToResolve (a, b)
    local ctype, x, y = ns.Classify(a, b)

    if ctype == "hard" and not ns.ResolvedType(y) then
        return y, ns.HardType(x)
    elseif ctype == "neither_hard" then
        local atype, btype = ns.ResolvedType(a), ns.ResolvedType(b)

        if atype and not btype then
            return b, atype
        elseif btype and not atype then
            return a, btype
        end
    end
end

local IsDeferred

--- DOCME
function M.DeferDecays ()
	IsDeferred = true
end

--- DOCME
function M.MakeClusterFuncs (ops)
	local resize, decay, resolve = ops.resize, MakeDecay(ops.decay_item), MakeResolve(ops.resolve_item)

	local function DoDecays ()
		ApplyChanges(resize, ToDecay, decay)

		ConnectionGen = ConnectionGen + 1
	end

	return CanConnect, function(how, a, b)
		local aparent, bparent = a.parent, b.parent

		if how == "connect" then -- n.b. display object does NOT exist yet...
			IsDeferred = true -- defer any decays introduced by the next two calls

			ns.BreakConnections(a)
			ns.BreakConnections(b)

			aparent.bound, bparent.bound = aparent.bound + a.bound_bit, bparent.bound + b.bound_bit

			local rnode, rtype = FindNodeToResolve(a, b)

			if rnode then
				OnFoundHard = error -- any hard nodes along the way violate the node's unresolved state

				dfs.VisitTopLevel(ConnectAlg, DoConnect, rnode, Opts)
			end

			local adgen, bdgen = ToDecay[aparent], ToDecay[bparent]

			if adgen == ConnectionGen and adgen == ToResolve[bparent] then
				ToResolve[bparent] = nil
			elseif bdgen == ConnectionGen and bdgen == ToResolve[aparent] then
				ToResolve[aparent] = nil
			end
			--[=[
			for index, gen in pairs(ToDecay) do -- breaking old connections can put boxes in the to-decay list, but
												-- the new connection might put them in the to-resolve list; these
												-- boxes are already resolved, so remove them from both lists
				if gen == ConnectionGen and ToResolve[index] == gen then
--print("MIRBLE")
					ToDecay[index], ToResolve[index] = nil
				end
			end
			]=]
-- seems to be missing that it's decaying, but the other thing WILL be resolved?
			ApplyChanges(resize, ToDecay, decay)

			if rtype then
				ApplyChanges(resize, ToResolve, resolve, rtype)
			end
			-- if wasn't reachable from "output", rebuild
--DUMP_INFO("connect")
			ConnectionGen, IsDeferred = ConnectionGen + 1
		elseif how == "disconnect" then -- ...but here it usually does, cf. note in FadeAndDie()
			aparent.bound, bparent.bound = aparent.bound - a.bound_bit, bparent.bound - b.bound_bit

			local ncandidates, x, y = EnumerateDecayCandidates(a, b)

			OnFoundHard = CanReachHardNode -- we throw away decay candidates if any node has a hard connection

			if ncandidates == 2 then -- not a hard connection, so either node is a candidate...
				ExploreDisconnectedNode(x)
			end

			if ncandidates >= 1 then -- ...whereas in a hard connection, only the non-hard one is
				ExploreDisconnectedNode(y)
			end
--DUMP_INFO("disconnect")
			if ncandidates > 0 and not IsDeferred then -- defer disconnections happening as a side effect of a connection or deletion
				DoDecays()
			end
			-- if was reachable from "output", rebuild
		end
	end, DoDecays
end

--- DOCME
function M.RemoveFromDecayList (box)
	ToDecay[box] = nil
end

--- DOCME
function M.ResumeDecays ()
	IsDeferred = false
end
--[=[
function DUMP_INFO (why)
	local stage = display.getCurrentStage()
	local Connected={}
	local nc = require("corona_ui.patterns.node_cluster")
	print("DUMP", why)
	for i = 1, stage.numChildren do
		local p = stage[i]
		if p.numChildren and p.numChildren >= 2 and p[2].text then
			print("ELEMENT:", p, p[2].text)

			local info = {}
			for k, v in pairs(p) do
if k ~= "_class" and k ~= "_proxy" and k ~= "back" then -- skip some unenlightening stuff
				info[#info + 1] = ("%s = %s"):format(tostring(k), tostring(v))
end
			end
			print("{ " .. table.concat(info, ", ") .. " }")

			for j = 3, p.numChildren do
				local _, n = nc.GetConnectedObjects(p[j], Connected)

				if n > 0 then
					print("NODE: ", p[j + 1].text, NODE_INFO(p[j]))

					for k = 1, n do
						print("CONNECTED TO: ", NODE_INFO(Connected[k]))
					end

					print("")
				end
			end

			print("")
		end
	end
end
--]=]
return M