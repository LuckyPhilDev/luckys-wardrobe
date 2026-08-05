-- luacheck: globals debugprofilestop

-- Lucky's Wardrobe: a stopwatch for the work the addon does, so a report of
-- dropped frames can be answered with numbers instead of a guess. Everything
-- measured is kept in memory for the session and printed on request.
--
-- The frame sampler answers the question timings alone cannot: whether a slow
-- frame was slow because of work measured here, or in spite of it. A frame that
-- took 80ms with 78ms of measured work in it is ours to fix; the same frame
-- with 0.2ms of measured work is not.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Perf = {}

local Perf = LuckysWardrobe.Perf

-- A frame this long is one a player feels: it halves a 60fps display.
local SLOW_FRAME_MS = 33

-- The client's own millisecond timer. Held on the table so tests can wind it
-- by hand rather than waiting for real time to pass.
Perf.Clock = debugprofilestop

local measures = {}
local names = {}
local openedAt = {}
-- Measures nest: a page refresh contains the entry rebuild it triggered. Only
-- the outermost adds to a frame's total, or the same milliseconds get counted
-- once for every measure wrapped around them.
local depth = 0
local frameWork = 0
local frames, slowFrames, worstFrame, worstFrameWork, watchedWork = 0, 0, 0, 0, 0

local function measure(name)
    local entry = measures[name]
    if not entry then
        entry = { count = 0, total = 0, worst = 0, last = 0 }
        measures[name] = entry
        names[#names + 1] = name
    end
    return entry
end

function Perf:Record(name, milliseconds)
    local entry = measure(name)
    entry.count = entry.count + 1
    entry.total = entry.total + milliseconds
    entry.last = milliseconds
    if milliseconds > entry.worst then entry.worst = milliseconds end
    if depth == 0 then frameWork = frameWork + milliseconds end
end

--- Records that something happened, without timing it.
function Perf:Count(name)
    local entry = measure(name)
    entry.count = entry.count + 1
end

--- Starts timing a piece of work that finishes inside the same frame. Work that
--- spans frames is measured a frame at a time instead, which is the number that
--- says whether a player feels it.
function Perf:Begin(name)
    openedAt[name] = Perf.Clock()
    depth = depth + 1
end

function Perf:End(name)
    local began = openedAt[name]
    if not began then return end

    openedAt[name] = nil
    depth = math.max(depth - 1, 0)
    self:Record(name, Perf.Clock() - began)
end

--- Called once a frame while whatever is being watched is on screen. The work
--- recorded since the last call is what that frame spent inside measured code.
function Perf:Frame(elapsedSeconds)
    local frameMilliseconds = elapsedSeconds * 1000
    frames = frames + 1
    watchedWork = watchedWork + frameWork
    if frameMilliseconds >= SLOW_FRAME_MS then slowFrames = slowFrames + 1 end
    if frameMilliseconds > worstFrame then
        worstFrame = frameMilliseconds
        worstFrameWork = frameWork
    end

    -- A measure still open when the frame ends never finished, which means
    -- something threw part way through it. An error thrown every frame costs a
    -- player their frame rate whether or not they have errors on screen, so
    -- naming it here is often the whole answer.
    for name in pairs(openedAt) do
        self:Count("unfinished " .. name)
        openedAt[name] = nil
    end
    depth = 0
    frameWork = 0
end

function Perf:Reset()
    measures, names, openedAt = {}, {}, {}
    depth, frameWork = 0, 0
    frames, slowFrames, worstFrame, worstFrameWork, watchedWork = 0, 0, 0, 0, 0
end

function Perf:IsEmpty()
    return #names == 0 and frames == 0
end

--- One line per measure, in the order each was first seen, then a line for the
--- frames watched. Returned rather than printed so a test can read them.
function Perf:Report()
    local S = LuckysWardrobe.Strings.perf
    local lines = {}

    for _, name in ipairs(names) do
        local entry = measures[name]
        if entry.total > 0 then
            lines[#lines + 1] = S.timedLine:format(
                name, entry.count, entry.total, entry.total / entry.count, entry.worst, entry.last)
        else
            lines[#lines + 1] = S.countedLine:format(name, entry.count)
        end
    end

    if frames > 0 then
        lines[#lines + 1] = S.framesLine:format(frames, watchedWork / frames, slowFrames, SLOW_FRAME_MS)
        lines[#lines + 1] = S.worstFrameLine:format(worstFrame, worstFrameWork)
    end

    return lines
end

function Perf:PrintReport()
    local S = LuckysWardrobe.Strings.perf
    local say = LuckysWardrobe.Utils.Say

    if self:IsEmpty() then
        say(S.nothing)
        return
    end

    say(S.header)
    for _, line in ipairs(self:Report()) do say("  " .. line) end
end
