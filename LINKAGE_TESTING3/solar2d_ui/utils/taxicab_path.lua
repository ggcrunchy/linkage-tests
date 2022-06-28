--- Utility for closed paths built from horizontal and vertical moves, i.e. taxicab geometry.
-- Path corners are blended with arcs; the results are like generalized rounded rect strokes.

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
local abs = math.abs
local cos = math.cos
local pi = math.pi
local sin = math.sin
local unpack = unpack

-- Exports --
local M = {}

--
--
--

local TaxicabPath = {}

TaxicabPath.__index = TaxicabPath

--
--
--

function TaxicabPath:GetPoints ()
	assert(self.m_is_closed, "Path incomplete")

	return unpack(self)
end

--
--
--

local Coeffs = { 1, 0 } -- cos(0), sin(0)

local QuadrantInterior = 3

local FullQuadrantAngle = pi / 2

for i = 1, QuadrantInterior do
	local t = i / (QuadrantInterior + 1)
	local angle = t * FullQuadrantAngle

	Coeffs[#Coeffs + 1] = cos(angle)
	Coeffs[#Coeffs + 1] = sin(angle)
end

local function Append (path, x, y)
	path[#path + 1] = x
	path[#path + 1] = y
end

-- We begin and an arc a distance of R from the next point:
--
--
--           DR1
-- --------O===>P
--        P1    ! DR2
--              !
--              V
--         C    O PR
--              |
--              |
--              |
--
-- We want to interpolate from P1 to PR. We can do this with a circular arc centered at C:
--
-- --------O----O
--         ^    |
--      B1 !    |
--         !    |
--         C===>O
--           B2 |
--              |
--              |
--
-- C is "below" P1, so we can reach it by following PR backward along DR1. DR1 doubles as our
-- second basis vector; we get -DR2 as the first one in a similar way. Also, while we start
-- from PR (rather than P), we never actually append it, in order to streamline the code on
-- the first move, where we emit PR but no quadrant.

local function AppendQuadrant (path, prx, pry, drx, dry, b2x, b2y)
	local cx, cy, b1x, b1y = prx - b2x, pry - b2y, -drx, -dry -- TODO: diagram

	for i = 1, #Coeffs, 2 do
		local cosa, sina = Coeffs[i], Coeffs[i + 1]

		Append(path, cx + b1x * cosa + b2x * sina, cy + b1y * cosa + b2y * sina)
	end
end

local function GetDiffs (comp, delta, radius)
	local dr = delta < 0 and -radius or radius

	if comp == "x" then
		return delta, 0, dr, 0
	else
		return 0, delta, 0, dr
	end
end

local Epsilon = 1e-3

--- DOCME
function TaxicabPath:MoveBy (comp, delta)
	local basis2 = self.m_basis2

	assert(not self.m_is_closed, "Loop closed")
	assert(comp == "x" or comp == "y", "Invalid move component")
	assert(basis2[comp] == 0, "Must switch axis each move")
	assert(delta and delta ~= 0, "Must provide non-0 move")

	local dx, dy, drx, dry = GetDiffs(comp, delta, self.m_radius)
	local not_empty, px, py = #self > 0

	if not_empty then
		px, py = self.m_px, self.m_py
	else
		px, py = self.m_x0, self.m_y0
	end

	local prx, pry = px + drx, py + dry

	if not_empty then -- bridge the last segment and the new one?
		AppendQuadrant(self, prx, pry, drx, dry, basis2.x, basis2.y)		
	end

	Append(self, prx, pry)

	px, py, basis2.x, basis2.y = px + dx, py + dy, drx, dry

	if abs(px - self.m_x0) + abs(py - self.m_y0) <= Epsilon then
		local x, y = self[1], self[2]

		drx, dry = x - px, y - py -- P = P0; P0 + DeltaR = (x, y)

		AppendQuadrant(self, px + drx, py + dry, drx, dry, basis2.x, basis2.y) 
		Append(self, x, y) -- close the loop

		self.m_is_closed = true
	else
		self.m_px, self.m_py = px, py
	end
end

--
--
--

--- DOCME
function M.New (x, y, radius)
	return setmetatable({ m_basis2 = { x = 0, y = 0 }, m_x0 = x, m_y0 = y, m_radius = radius }, TaxicabPath)
end

--
--
--

return M