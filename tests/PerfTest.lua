-- luacheck: globals LuckysWardrobe
-- luacheck: ignore 121

LuckysWardrobe = {}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/Perf.lua")

local Perf = LuckysWardrobe.Perf

-- Time is wound by hand: a measurement of real elapsed time would make every
-- assertion below a race.
local clock = 0
Perf.Clock = function() return clock end

local function elapse(milliseconds)
    clock = clock + milliseconds
end

local function reportText()
    return table.concat(Perf:Report(), "\n")
end

assert(Perf:IsEmpty(), "nothing is measured before anything happens")
assert(#Perf:Report() == 0, "an empty session reports nothing")

Perf:Begin("work")
elapse(12)
Perf:End("work")
Perf:Begin("work")
elapse(6)
Perf:End("work")

assert(not Perf:IsEmpty(), "measuring something fills the report")
assert(reportText():find("work: 2, 18 ms total, 9.0 ms each, worst 12.0, last 6.0"),
    "reported the count, the total, the average, the worst, and the most recent")

-- An unmatched End is what a mid-measurement error leaves behind, and it must
-- not report a wild number.
Perf:End("never started")
assert(not reportText():find("never started"), "ignored an end with no beginning")

Perf:Count("event")
Perf:Count("event")
assert(reportText():find("event: 2"), "counted what is not worth timing")

-- Frames.

Perf:Frame(0.010)
assert(reportText():find("frames watched: 1"), "counted the frame")
assert(reportText():find("18.0 ms of measured work each"), "charged the frame with the work before it")
assert(reportText():find("worst frame: 10 ms, 18 ms of it measured work"),
    "named the worst frame and how much of it was ours")

Perf:Frame(0.050)
assert(reportText():find("1 over 33 ms"), "counted the frames a player would feel")
assert(reportText():find("worst frame: 50 ms, 0 ms of it measured work"),
    "a slow frame with no measured work in it is not ours")

-- Nested measures. A refresh that contains a rebuild must not charge a frame
-- for the same milliseconds twice.

Perf:Reset()
Perf:Begin("outer")
elapse(5)
Perf:Begin("inner")
elapse(20)
Perf:End("inner")
elapse(5)
Perf:End("outer")
Perf:Frame(0.040)

assert(reportText():find("outer: 1, 30 ms total"), "the outer measure spans the inner one")
assert(reportText():find("inner: 1, 20 ms total"), "the inner measure is reported in its own right")
assert(reportText():find("worst frame: 40 ms, 30 ms of it measured work"),
    "the frame is charged the outer measure once, not the inner one again")

-- Work that throws part way through leaves its measure open. The frame that
-- ends says so, rather than charging the next frame with the leftovers.

Perf:Reset()
Perf:Begin("threw")
elapse(9)
Perf:Frame(0.020)
assert(reportText():find("unfinished threw: 1"), "named the measure that never finished")
assert(reportText():find("worst frame: 20 ms, 0 ms of it measured work"),
    "an unfinished measure is not counted as work done")

Perf:Begin("fine")
elapse(4)
Perf:End("fine")
Perf:Frame(0.030)
assert(reportText():find("fine: 1, 4 ms total"), "measuring carries on after something threw")
assert(reportText():find("worst frame: 30 ms, 4 ms of it measured work"),
    "the abandoned measure left no depth behind to swallow the next one")

-- What a player actually sees in chat.

local printed = {}
local realPrint = print
print = function(line) printed[#printed + 1] = line end
Perf:PrintReport()
Perf:Reset()
Perf:PrintReport()
print = realPrint

assert(printed[1]:find(LuckysWardrobe.Strings.perf.header, 1, true), "led with the header")
assert(table.concat(printed, "\n"):find("fine: 1"), "listed each measure under it")
assert(printed[#printed]:find(LuckysWardrobe.Strings.perf.nothing, 1, true),
    "said so plainly when there is nothing to report")

-- Reset.

Perf:Reset()
assert(Perf:IsEmpty() and #Perf:Report() == 0, "resetting clears every measure and the frames")

print("Lucky's Wardrobe perf test passed")
