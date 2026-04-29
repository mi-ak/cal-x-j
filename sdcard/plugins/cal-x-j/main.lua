-- cal-x-j: Japanese Calendar Plugin for XTEINK X4 Flow
-- Author: mi-ak
-- GitHub: https://github.com/mi-ak
-- Version: 0.1.0
-- =====================================================

-- ── Constants ──────────────────────────────────────
local PLUGIN_VERSION = "0.1.0"
local CACHE_DIR      = "/plugins/cal-x-j"
local DATE_CACHE     = CACHE_DIR .. "/lastdate.txt"
local SETTINGS_PATH  = CACHE_DIR .. "/settings.txt"
local FALLBACK_Y     = 2026
local csvHolidaysCache = {}

local FONTS = { ui12 = FONT_UI_12, small = FONT_SMALL,jp_ui12 = FONT_UI_12,jp_small = FONT_SMALL }
FONT_CONFIG = FONTS

local STR = {
    HOLIDAY_DATA_FAIL = "祝日データ読み込み失敗",
    WEEK_START_HINT = "上: 週頭(%s)",
    YEAR_MONTH_HINT = "下: 操作表示",
    YEAR_VIEW_HINT = "上:曜日切替(%s)  下: 操作表示",
    MONTH_TITLE_FORMAT = "%d年 %d月      %s",
    YEAR_TITLE_FORMAT = "%d年     %s",
    MONTH_LABEL_FORMAT = "%d月",
    WEEK_NUMBER_FORMAT = "W%02d",
    HOLIDAY_MARK = "祝",
    LEFT_LABEL = "<",
    RIGHT_LABEL = ">",
    INITIALIZATION_FAILED_PREFIX = "初期化失敗: ",
    GENERIC_ERROR = "エラー",
    EXIT = "EXIT",
    SELECT_MONTH = "選択月",
    YEAR_VIEW = "年表示",
    GOTO_MONTH = "この月へ",
}

local BUTTON = {
    exit = STR.EXIT,
    selectMonth = STR.SELECT_MONTH,
    yearView = STR.YEAR_VIEW,
    left = STR.LEFT_LABEL,
    right = STR.RIGHT_LABEL,
    none = "",
}

local KEY = {
    back = "back",
    left = "left",
    right = "right",
    up = "up",
    down = "down",
    confirm = "confirm",
}

local FIXED_HOLIDAYS = {
    ["01-01"] = "元日",
    ["01-02"] = "休暇日", --　特殊ケース
    ["01-03"] = "休暇日", --　特殊ケース
    ["02-11"] = "建国記念の日",
    ["04-29"] = "昭和の日",
    ["05-03"] = "憲法記念日",
    ["05-04"] = "みどりの日",
    ["05-05"] = "こどもの日",
    ["08-11"] = "山の日",
    ["12-30"] = "休暇日",--　特殊ケース
    ["12-31"] = "休暇日",--　特殊ケース
    ["11-03"] = "文化の日",
    ["11-23"] = "勤労感謝の日",
}

local VARIABLE_HOLIDAYS = {
    [2026] = {
        ["01-12"] = "成人の日",
        ["02-23"] = "天皇誕生日",
        ["03-20"] = "春分の日",
        ["05-06"] = "休日",
        ["07-20"] = "海の日",
        ["09-21"] = "敬老の日",
        ["09-22"] = "休日",
        ["09-23"] = "秋分の日",
        ["10-12"] = "スポーツの日",
    },
    [2027] = {
        ["01-11"] = "成人の日",
        ["02-23"] = "天皇誕生日",
        ["03-21"] = "春分の日",
        ["03-22"] = "休日",
        ["07-19"] = "海の日",
        ["09-20"] = "敬老の日",
        ["09-23"] = "秋分の日",
        ["10-11"] = "スポーツの日",
    },
    [2028] = {
        ["01-10"] = "成人の日",
        ["02-23"] = "天皇誕生日",
        ["03-20"] = "春分の日",
        ["07-17"] = "海の日",
        ["09-18"] = "敬老の日",
        ["09-22"] = "秋分の日",
        ["10-09"] = "スポーツの日",
    },
}

local YEAR_VIEW_CONFIG = {
    holidayMarkerPrefix = "h",
    holidayMarkerOffsetX = -5,
    holidayMarkerOffsetY = 3,
    holidayMarkerFont = FONTS.small,
    holidayMarkerColor = COLOR_DARK_GRAY,
    holidayMarkerStyle = STYLE_BOLD,
    quarterPrefix = "q",
    quarterOffsetX = 4,
    quarterOffsetY = 4-2,
    quarterFont = FONTS.small,
    quarterColor = COLOR_DARK_GRAY,
    quarterStyle = STYLE_BOLD,
}

local function getCurrentYear()
    local dt = os.date("*t")
    if dt and type(dt.year) == "number" and dt.year >= 2000 then
        return dt.year
    end
    return FALLBACK_Y
end

-- WIFIは封印（ネットワーク不要）

local DAY_HEADER = {
    [1] = {"月","火","水","木","金","土","日"},
    [0] = {"日","月","火","水","木","金","土"},
    [6] = {"土","日","月","火","水","木","金"},
}

local WEEK_START_LABEL = {
    [1] = "月曜",
    [0] = "日曜",
    [6] = "土曜",
}

-- Month view layout
local MV_HDR_H  = 90   -- header total height
local MV_DOW_H  = 44   -- day-of-week row height
local MV_GRID_Y = MV_HDR_H + MV_DOW_H   -- 134
local MV_GRID_H = 616                    -- 750 - 134
local MV_CELL_W = 68                     -- floor(480/7): 7*68=476, margin=4
local MV_CELL_X = 2                      -- left margin

-- Year view layout  (3 cols × 4 rows of mini calendars)
local YV_HDR_H  = 65
local YV_GRID_Y = 65
local YV_HINT_Y = 750
local YV_COLS   = 3
local YV_ROWS   = 4
local YV_CEL_W  = 160                    -- 480/3
local YV_CEL_H  = 171                    -- floor(685/4) = floor((YV_HINT_Y-YV_HDR_H)/4)

-- ── State ──────────────────────────────────────────
local viewYear, viewMonth
local curYear, curMonth, curDay  -- today (curDay=0 if unknown)
local startDow                  -- 1=Mon-start, 0=Sun-start, 6=Sat-start
local holidays                   -- { ["YYYY-MM-DD"] = "name" }
local state                      -- "display"|"error"
local viewMode                   -- "month"|"year"
local selMonth                   -- cursor in year view (1-12)
local showHints                  -- toggle hint/button label display
local showQuarter                -- show quarter labels in year view
local showHolidayCount           -- show holiday counts in year view
local showWeekNumber             -- show week numbers in month view
local needsRedraw, firstDraw
local errorMsg

local skipFrames                 -- ignore inputs for N frames after init

-- ── Pure helpers ───────────────────────────────────
local function daysInMonth(y, m)
    local t = os.time({year=y, month=m+1, day=0, hour=12, min=0, sec=0})
    return os.date("*t", t).day
end

local function firstWday(y, m)
    -- 0=Sun, 1=Mon, ..., 6=Sat  for the 1st of y/m
    local t = os.time({year=y, month=m, day=1, hour=12, min=0, sec=0})
    return os.date("*t", t).wday - 1
end

local function startCol(y, m)
    local wd = firstWday(y, m)
    if startDow == 1 then
        return math.floor((wd + 6) % 7)  -- Mon→0 … Sun→6
    elseif startDow == 0 then
        return wd                          -- Sun→0 … Sat→6
    else
        return math.floor((wd + 1) % 7)     -- Sat→0, Sun→1, Mon→2 … Fri→6
    end
end

local function weekNumber(y, m, d)
    local t = os.time({year=y, month=m, day=d, hour=12, min=0, sec=0})
    local u = tonumber(os.date("%U", t))
    if not u then return 0 end
    return u + 1
end

local function weekStartConfig()
    local days = DAY_HEADER[startDow] or DAY_HEADER[1]
    if startDow == 1 then
        return days, 5, 6
    elseif startDow == 0 then
        return days, 6, 0
    else
        return days, 0, 1
    end
end

local function weekStartLabel()
    return WEEK_START_LABEL[startDow] or WEEK_START_LABEL[1]
end

-- Convert western year to Japanese era string (令和 / 平成)
local function wareki(y)
    if y >= 2019 then
        return string.format("令和%d", y - 2018)
    elseif y >= 1989 then
        return string.format("平成%d", y - 1988)
    else
        return ""
    end
end

-- Cycle viewYear through {curYear-1, curYear, curYear+1}
local function cycleYear(cur, dir)
    local base = curYear
    local idx  = (cur - base) + 2          -- maps {-1,0,1} → {1,2,3}
    idx = math.floor((idx - 1 + dir) % 3) + 1
    local offs = {-1, 0, 1}
    return base + offs[idx]
end

local function hkey(y, m, d)
    return string.format("%04d-%02d-%02d", y, m, d)
end

local function cachePath(y)
    return CACHE_DIR .. "/holidays_" .. tostring(y) .. ".json"
end

local function safeExists(path)
    local ok, result = pcall(fs.exists, path)
    return ok and result or false
end

local function safeReadFile(path)
    local ok, result = pcall(fs.readFile, path)
    if ok then
        return result
    end
    return nil
end

local function safeWriteFile(path, content)
    return pcall(fs.writeFile, path, content)
end

local function loadSettings()
    if safeExists(SETTINGS_PATH) then
        local s = safeReadFile(SETTINGS_PATH)
        if s then
            local result = {}
            local v = s:match("startDow%s*=%s*(%d+)")
            if v == "1" or v == "0" or v == "6" then
                result.startDow = tonumber(v)
            else
                v = s:match("startMonday%s*=%s*(%d)")
                if v == "1" then result.startDow = 1 end
                if v == "0" then result.startDow = 0 end
                v = s:match("startMonday%s*=%s*(true|false)")
                if v == "true" then result.startDow = 1 end
                if v == "false" then result.startDow = 0 end
            end
            local mode = s:match("viewMode%s*=%s*(%a+)")
            if mode == "month" or mode == "year" then
                result.viewMode = mode
            end
            local y = s:match("viewYear%s*=%s*(%d+)")
            if y then
                result.viewYear = tonumber(y)
            end
            local m = s:match("viewMonth%s*=%s*(%d+)")
            if m then
                result.viewMonth = tonumber(m)
            end
            local sh = s:match("showHints%s*=%s*(%d+)")
            if sh then
                result.showHints = tonumber(sh) ~= 0
            end
            local sq = s:match("showQuarter%s*=%s*(%d+)")
            if sq then
                result.showQuarter = tonumber(sq) ~= 0
            end
            local shc = s:match("showHolidayCount%s*=%s*(%d+)")
            if shc then
                result.showHolidayCount = tonumber(shc) ~= 0
            end
            local swn = s:match("showWeekNumber%s*=%s*(%d+)")
            if swn then
                result.showWeekNumber = tonumber(swn) ~= 0
            end
            local sm = s:match("selMonth%s*=%s*(%d+)")
            if sm then
                result.selMonth = tonumber(sm)
            end
            if next(result) then
                return result
            end
        end
    end
    return nil
end

local function saveSettings()
    local content = string.format("showHints=%d\nshowQuarter=%d\nshowHolidayCount=%d\nshowWeekNumber=%d\nstartDow=%d\nviewMode=%s\nviewYear=%d\nviewMonth=%d\nselMonth=%d\n",
                                  showHints and 1 or 0,
                                  showQuarter and 1 or 0,
                                  showHolidayCount and 1 or 0,
                                  showWeekNumber and 1 or 0,
                                  startDow, viewMode or "month", viewYear or getCurrentYear(), viewMonth or 1, selMonth or 1)
    safeWriteFile(SETTINGS_PATH, content)
end


local function loadCsvHolidays(year)
    if csvHolidaysCache[year] then
        return csvHolidaysCache[year]
    end

    local t = {}
    for md, name in pairs(FIXED_HOLIDAYS) do
        t[string.format("%04d-%s", year, md)] = name
    end
    for md, name in pairs(VARIABLE_HOLIDAYS[year] or {}) do
        t[string.format("%04d-%s", year, md)] = name
    end
    csvHolidaysCache[year] = t
    return t
end

local function mergeHolidayTables(...)
    local merged = {}
    for _, tbl in ipairs({...}) do
        if tbl then
            for k, v in pairs(tbl) do
                merged[k] = v
            end
        end
    end
    return merged
end

local function loadHolidayCsv(year)
    local prevYear = loadCsvHolidays(year - 1)
    local thisYear = loadCsvHolidays(year)
    local nextYear = loadCsvHolidays(year + 1)
    return mergeHolidayTables(prevYear, thisYear, nextYear)
end

-- Safe UTF-8 truncation at 3-byte CJK boundaries
local function limitStr(s, maxBytes)
    if #s <= maxBytes then return s end
    local n = math.floor(maxBytes / 3) * 3
    return string.sub(s, 1, n) .. "…"
end

local function offsetDate(y, m, d, offset)
    local t = os.time({year=y, month=m, day=d, hour=12, min=0, sec=0})
    local nt = t + offset * 86400
    local dt = os.date("*t", nt)
    return dt.year, dt.month, dt.day
end

local function isConsecutiveHoliday(y, m, d)
    if not holidays then return false end
    local py, pm, pd = offsetDate(y, m, d, -1)
    local ny, nm, nd = offsetDate(y, m, d, 1)
    return holidays[hkey(py, pm, pd)] or holidays[hkey(ny, nm, nd)]
end

-- ── Date detection ─────────────────────────────────
local function detectDate()
    local ok, dt = pcall(os.date, "*t")
    if not ok then
        return false
    end
    if dt and dt.year and dt.year > 2000 then
        curYear  = dt.year
        curMonth = dt.month
        curDay   = dt.day
        -- Persist for offline use after sleep/reset
        safeWriteFile(DATE_CACHE,
            string.format("%04d-%02d-%02d", curYear, curMonth, curDay))
        return true
    end
    return false
end

local function loadCachedDate()
    if safeExists(DATE_CACHE) then
        local s = safeReadFile(DATE_CACHE)
        if s then
            local y, m, d = string.match(s, "(%d%d%d%d)-(%d%d)-(%d%d)")
            if y then
                curYear  = tonumber(y)
                curMonth = tonumber(m)
                curDay   = tonumber(d)
                return true
            end
        end
    end
    return false
end

-- ── Holiday management ─────────────────────────────
function beginFetch()
    -- WiFi無し：CSVから直接読み込み
    local c = loadHolidayCsv(viewYear)
    if c then
        holidays = c
    else
        holidays = {}
    end
    needsRedraw = true
end

local function switchYear(newY)
    viewYear = newY
    -- CSVモードでは年切替時もCSVを再ロードする
    local c = loadHolidayCsv(viewYear)
    if c and next(c) then
        holidays = c
    else
        holidays = {}
    end
    needsRedraw = true
end

-- ── Month view drawing ─────────────────────────────
local function mvHeader()
    local hYear  = viewYear  or getCurrentYear()
    local hMonth = viewMonth or 1
    local hWareki = wareki(hYear)
    local title = string.format(STR.MONTH_TITLE_FORMAT, hYear, hMonth, hWareki)
    -- Use ASCII < > (◀▶ not supported by font)
    local aw = gui.getTextWidth(FONTS.ui12, "<")
    gui.drawText(FONTS.ui12, 6,           4, "<", true, STYLE_BOLD)
    gui.drawCenteredText(FONTS.jp_ui12,      4, title, true, STYLE_BOLD)
    gui.drawText(FONTS.ui12, 480 - aw - 6, 4, ">", true, STYLE_BOLD)

    if showHints then
        local sub1 = string.format(STR.WEEK_START_HINT, weekStartLabel())
        gui.drawText(FONTS.jp_small,480 - aw - 100, 35, sub1, COLOR_DARK_GRAY, STYLE_REGULAR)
        local sub2 = STR.YEAR_MONTH_HINT
        gui.drawText(FONTS.jp_small,480 - aw - 100, 55, sub2, COLOR_DARK_GRAY, STYLE_REGULAR)
    end

    gui.drawLine(0, MV_HDR_H - 1, 480, MV_HDR_H - 1, 1, true)
end

local function mvDOW()
    local days, satC, sunC = weekStartConfig()
    for col = 0, 6 do
        local s     = days[col + 1]
        local color = (col == satC or col == sunC) and COLOR_DARK_GRAY or true
        local tw    = gui.getTextWidth(FONTS.jp_small, s)
        local x     = MV_CELL_X + col * MV_CELL_W + math.floor((MV_CELL_W - tw) / 2)
        -- Center vertically in DOW area: top margin of 10px within the 44px row
        gui.drawText(FONTS.jp_small, x, MV_HDR_H + 10, s, color, STYLE_BOLD)
    end
    -- Draw separator at bottom of DOW area
    gui.drawLine(0, MV_GRID_Y - 1, 480, MV_GRID_Y - 1, 1, true)
end

local function mvGrid()
    local yYear  = viewYear or getCurrentYear()
    local yMonth = viewMonth or 1
    local dim   = daysInMonth(yYear, yMonth)
    local sc    = startCol(yYear, yMonth)
    local total = sc + dim
    local weeks = math.floor((total + 6) / 7)
    local rowH  = math.floor(MV_GRID_H / weeks)

    local prevYear, prevMonth = yYear, yMonth - 1
    if prevMonth < 1 then
        prevYear = yYear - 1
        prevMonth = 12
    end
    local nextYear, nextMonth = yYear, yMonth + 1
    if nextMonth > 12 then
        nextYear = yYear + 1
        nextMonth = 1
    end
    local prevDim = daysInMonth(prevYear, prevMonth)

    -- True if viewing a month entirely in the past
    local isViewPast = (yYear < curYear) or (yYear == curYear and yMonth < curMonth)

    -- True if a given date is in the past (before today)
    local function isDatePast(y, m, d)
        if y < curYear then return true end
        if y == curYear and m < curMonth then return true end
        if y == curYear and m == curMonth and d < curDay then return true end
        return false
    end

    local function drawAdjacentDate(cx, cy, y, m, d, isWeekend, isSunday)
        -- Per-cell background for past adjacent dates when NOT already covered by isViewPast fill
        if isViewPast or isDatePast(y, m, d) then
            gui.fillRoundedRect(cx, cy, MV_CELL_W, rowH, 0, COLOR_WHITE)
            gui.fillRoundedRect(cx, cy, MV_CELL_W, rowH, 0, COLOR_LIGHT_GRAY)
        end
        local label = string.format("%d/%d", m, d)
        local tw = gui.getTextWidth(FONTS.small, label)
        local nx = cx + math.floor((MV_CELL_W - tw) / 2)
        local ny = cy + math.floor((rowH - 12) / 2)
        local isHoliday = holidays and holidays[hkey(y, m, d)]
        local isPastAdj = isDatePast(y, m, d)
        -- Past bg: weekday black, holiday/weekend dark gray; future: same convention
        local color = (isHoliday or isWeekend) and COLOR_DARK_GRAY or true
        gui.drawText(FONTS.small, nx, ny, label, color, STYLE_REGULAR)
        if isSunday then
            local weekNo = weekNumber(y, m, d)
            local weekLabel = string.format(STR.WEEK_NUMBER_FORMAT, weekNo)
            local ww = gui.getTextWidth(FONTS.small, weekLabel)
            gui.drawText(FONTS.small, cx + MV_CELL_W - ww - 3, cy + 2, weekLabel, COLOR_DARK_GRAY, STYLE_REGULAR)
        end
        if isHoliday then
            gui.drawText(FONTS.jp_small, cx + 2, cy + 4, STR.HOLIDAY_MARK, COLOR_DARK_GRAY, STYLE_BOLD)
            local hname = holidays[hkey(y, m, d)]
            if hname then
                local s  = hname
                if isConsecutiveHoliday(y, m, d) then
                    s = limitStr(hname, 12)
                end
                local sw = gui.getTextWidth(FONTS.jp_small, s)
                local sx = cx + math.floor((MV_CELL_W - sw) / 2)
                local sy = cy + rowH - 18
                if sy < cy + rowH then
                    gui.drawText(FONTS.jp_small, sx, sy-5, s, COLOR_DARK_GRAY, STYLE_REGULAR)
                end
            end
        end
    end

    local _, satC, sunC = weekStartConfig()

    -- Fill leading blank cells with previous month dates
    for idx = 0, sc - 1 do
        local row = math.floor(idx / 7)
        local col = idx % 7
        local cx  = MV_CELL_X + col * MV_CELL_W
        local cy  = MV_GRID_Y + row * rowH
        local day = prevDim - sc + idx + 1
        drawAdjacentDate(cx, cy, prevYear, prevMonth, day, col == satC or col == sunC, col == sunC)
    end

    -- Fill trailing blank cells with next month dates
    for idx = sc + dim, weeks * 7 - 1 do
        local row = math.floor(idx / 7)
        local col = idx % 7
        local cx  = MV_CELL_X + col * MV_CELL_W
        local cy  = MV_GRID_Y + row * rowH
        local day = idx - (sc + dim) + 1
        drawAdjacentDate(cx, cy, nextYear, nextMonth, day, col == satC or col == sunC, col == sunC)
    end

    for d = 1, dim do
        local idx = sc + d - 1
        local row = math.floor(idx / 7)
        local col = idx % 7
        local cx  = MV_CELL_X + col * MV_CELL_W
        local cy  = MV_GRID_Y + row * rowH

        local key      = hkey(yYear, yMonth, d)
        local hname    = holidays and holidays[key]
        local isToday  = (yYear == curYear and yMonth == curMonth and d == curDay)
        local isPastDay = not isViewPast and isDatePast(yYear, yMonth, d)
        local isSat    = (col == satC)
        local isSun    = (col == sunC)
        local isHoliday = hname ~= nil
        local isCellPast = isViewPast or isPastDay  -- on a light gray background

        -- Per-cell background for past days (current month: only past days; past month: all cells)
        if isCellPast then
            gui.fillRoundedRect(cx, cy, MV_CELL_W, rowH, 0, COLOR_WHITE)
            gui.fillRoundedRect(cx, cy, MV_CELL_W, rowH, 0, COLOR_LIGHT_GRAY)
        end

        local numStr = tostring(d)
        local nw     = gui.getTextWidth(FONTS.ui12, numStr)

        if showWeekNumber and col == sunC then
            local weekNo = weekNumber(yYear, yMonth, d)
            local weekLabel = string.format(STR.WEEK_NUMBER_FORMAT, weekNo)
            local ww = gui.getTextWidth(FONTS.small, weekLabel)
            gui.drawText(FONTS.small, cx + MV_CELL_W - ww - 3, cy + 2, weekLabel, true, STYLE_REGULAR)
        end

        -- Vertically center; shift up a bit if holiday name follows
        local ny = cy + math.floor(rowH / 2) - (isHoliday and 14 or 8)
        local nx = cx + math.floor((MV_CELL_W - nw) / 2)

        -- Color logic:
        -- Past cell: weekday black, holiday/weekend dark gray (lighter)
        -- Future cell: weekday black, holiday/weekend dark gray
        local color
        local numStyle
        if isToday then
            color = COLOR_DARK_GRAY
            numStyle = STYLE_REGULAR
        elseif isCellPast then
            color = (isHoliday or isSat or isSun) and COLOR_DARK_GRAY or true
            numStyle = STYLE_REGULAR
        else
            color = (isHoliday or isSat or isSun) and COLOR_DARK_GRAY or true
            numStyle = STYLE_REGULAR
        end

        if isToday then
            gui.drawRoundedRect(cx + 2, cy + 2, MV_CELL_W - 4, rowH - 4, 3, 2, false)
            gui.drawRoundedRect(cx + 3, cy + 3, MV_CELL_W - 6, rowH - 6, 3, 2, false)
        end
        gui.drawText(FONTS.ui12, nx, ny, numStr, color, numStyle)

        if isHoliday then
            gui.drawText(FONTS.jp_small, cx + 2, cy + 4, STR.HOLIDAY_MARK, COLOR_DARK_GRAY, STYLE_BOLD)
            local s  = hname
            if isConsecutiveHoliday(yYear, yMonth, d) then
                s = limitStr(hname, 12)
            end
            local sw = gui.getTextWidth(FONTS.jp_small, s)
            local sx = cx + math.floor((MV_CELL_W - sw) / 2)
            local sy = cy + rowH - 18
            if sy < cy + rowH then
                gui.drawText(FONTS.jp_small, sx, sy-5, s, COLOR_DARK_GRAY, STYLE_REGULAR)
            end
        end
    end

    -- Light grid lines (drawn after fills so they appear on top)
    for r = 0, weeks do
        gui.drawLine(0, MV_GRID_Y + r * rowH, 480, MV_GRID_Y + r * rowH, 1, COLOR_LIGHT_GRAY)
    end
    for c = 1, 6 do
        gui.drawLine(MV_CELL_X + c * MV_CELL_W, MV_GRID_Y,
                     MV_CELL_X + c * MV_CELL_W, MV_GRID_Y + weeks * rowH, 1, COLOR_LIGHT_GRAY)
    end
end

local function drawMonthView()
    gui.clear()
    mvHeader()
    mvGrid()
    mvDOW()  -- drawn after grid fills so text is never covered
    if showHints then
        gui.drawButtonHints(BUTTON.exit, BUTTON.yearView, BUTTON.left, BUTTON.right)
    else
        gui.drawButtonHints(BUTTON.none, BUTTON.none, BUTTON.none, BUTTON.none)
    end
end

-- ── Year view drawing ──────────────────────────────
local function drawMini(mx, my, mw, mh, year, month, holidayCount)
    local isNow  = (year == curYear and month == curMonth)
    local isSel  = (month == selMonth)
    local isPast = (year < curYear) or (year == curYear and month < curMonth)

    -- Background: fill light gray for past months
    -- Note: gui.fillRect only supports black/white (bool); use fillRoundedRect with radius=0
    -- to get actual gray via fillRectDither on the device.
    if isPast then
        gui.fillRoundedRect(mx, my, mw, mh, 0, COLOR_LIGHT_GRAY)
    end

    -- Border: extra bold if selected, light gray otherwise
    if isSel then
        local borderColor = true
        gui.drawRect(mx,     my,     mw,     mh,     borderColor)
        gui.drawRect(mx + 1, my + 1, mw - 2, mh - 2, borderColor)
        gui.drawRect(mx + 2, my + 2, mw - 4, mh - 4, borderColor)
    else
        local borderColor = isPast and COLOR_DARK_GRAY or COLOR_LIGHT_GRAY
        gui.drawRect(mx, my, mw, mh, borderColor)
    end

    -- Month label: always true (black) for visibility
    local labelColor = true
    local label = string.format(STR.MONTH_LABEL_FORMAT, month)
    local lw    = gui.getTextWidth(FONTS.ui12, label)
    local ls    = isNow and STYLE_BOLD or STYLE_REGULAR
    gui.drawText(FONTS.ui12, mx + math.floor((mw - lw) / 2) - 1, my - 5, label, labelColor, ls)

    -- Quarter label in year view (fiscal style: Apr-Jun=q1, Jul-Sep=q2, Oct-Dec=q3, Jan-Mar=q4)
    if showQuarter then
        local quarter = math.floor(((month + 8) % 12) / 3) + 1
        local qlabel  = string.format("%s%d", YEAR_VIEW_CONFIG.quarterPrefix, quarter)
        local qColor  = isPast and COLOR_DARK_GRAY or YEAR_VIEW_CONFIG.quarterColor
        gui.drawText(YEAR_VIEW_CONFIG.quarterFont,
                     mx + YEAR_VIEW_CONFIG.quarterOffsetX,
                     my + YEAR_VIEW_CONFIG.quarterOffsetY,
                     qlabel,
                     qColor,
                     YEAR_VIEW_CONFIG.quarterStyle)
    end

    -- Holiday marker in year view
    if showHolidayCount and holidayCount and holidayCount > 0 then
        local marker = string.format("%s%d", YEAR_VIEW_CONFIG.holidayMarkerPrefix, holidayCount)
        local tw     = gui.getTextWidth(YEAR_VIEW_CONFIG.holidayMarkerFont, marker)
        local hColor = isPast and COLOR_DARK_GRAY or YEAR_VIEW_CONFIG.holidayMarkerColor
        gui.drawText(YEAR_VIEW_CONFIG.holidayMarkerFont,
                     mx + mw - tw + YEAR_VIEW_CONFIG.holidayMarkerOffsetX,
                     my + YEAR_VIEW_CONFIG.holidayMarkerOffsetY,
                     marker,
                     hColor,
                     YEAR_VIEW_CONFIG.holidayMarkerStyle)
    end

    local labelH = 22   -- enough for FONTS.ui12 (~16px glyph + padding)
    local dowH   = 15   -- enough for FONTS.small (~12px glyph + gap)
    local gridY  = my + labelH + dowH
    local gridH  = mh - labelH - dowH - 3

    local days, satC, sunC = weekStartConfig()
    local cw   = math.floor(mw / 7)

    -- Day numbers
    local dim   = daysInMonth(year, month)
    local sc    = startCol(year, month)
    local total = sc + dim
    local weeks = math.floor((total + 6) / 7)
    local rowH  = math.floor(gridH / (weeks > 0 and weeks or 1))

    -- Fill leading blank cells with COLOR_LIGHT_GRAY for current month (all are past days)
    if isNow then
        for idx = 0, sc - 1 do
            local row = math.floor(idx / 7)
            local col = idx % 7
            local dx  = mx + col * cw
            local dy  = gridY + row * rowH
            gui.fillRoundedRect(dx, dy, cw, rowH, 0, COLOR_LIGHT_GRAY)
        end
    end

    for d = 1, dim do
        local idx = sc + d - 1
        local row = math.floor(idx / 7)
        local col = idx % 7
        local dx  = mx + col * cw
        local dy  = gridY + row * rowH

        local key     = hkey(year, month, d)
        local hname   = holidays and holidays[key]
        local isToday   = (year == curYear and month == curMonth and d == curDay)
        local isPastDay = (year == curYear and month == curMonth and d < curDay)

        local numStr = tostring(d)
        local tw     = gui.getTextWidth(FONTS.small, numStr)
        local nx     = dx + math.floor((cw - tw) / 2)
        local ny     = dy + math.floor((rowH - 12) / 2)

        -- Background for past days in current month
        if isPastDay then
            gui.fillRoundedRect(dx, dy, cw, rowH, 0, COLOR_LIGHT_GRAY)
        end

        if isToday then
            local r = math.floor(math.min(cw, rowH) / 2) - 1
            if r < 3 then r = 3 end
            -- Outline circle only, not filled
            local color = (hname or isSat or isSun) and COLOR_DARK_GRAY or true
            gui.drawText(FONTS.small, nx, ny, numStr, color, STYLE_REGULAR)
            -- gui.drawCircle(dx + math.floor(cw / 2), dy + math.floor(rowH / 2), r, 2, false)
        else
            local isSat  = (col == satC)
            local isSun  = (col == sunC)
            local color = (hname or isSat or isSun) and COLOR_DARK_GRAY or true
            gui.drawText(FONTS.small, nx, ny, numStr, color, STYLE_REGULAR)
        end
    end

    -- DoW row: drawn last so fills don't cover it
    for col = 0, 6 do
        local color = (col == satC or col == sunC) and COLOR_DARK_GRAY or true
        local s  = days[col + 1]
        local tw = gui.getTextWidth(FONTS.jp_small, s)
        gui.drawText(FONTS.jp_small, mx + col * cw + math.floor((cw - tw) / 2),
                     my + labelH, s, color, STYLE_REGULAR)
    end
end

local function drawYearView()
    gui.clear()

    local yYear = viewYear or getCurrentYear()
    -- Header: 「2026年  令和8」(left/right = year navigation)
    local title = string.format(STR.YEAR_TITLE_FORMAT, yYear, wareki(yYear))
    gui.drawCenteredText(FONTS.jp_ui12, 4, title, true, STYLE_BOLD)

    -- Sub-hint: weekday toggle, view switch, and year navigation
    if showHints then
        local sub2 = string.format(STR.YEAR_VIEW_HINT, weekStartLabel())
        gui.drawCenteredText(FONTS.jp_small, 42, sub2, COLOR_DARK_GRAY, STYLE_REGULAR)
    end

    gui.drawLine(0, YV_HDR_H - 1, 480, YV_HDR_H - 1, 1, true)

    -- 12-month grid  (3×4)
    -- 年ビューでは週末を除いた祝日をカウント
    local yYear = viewYear or getCurrentYear()
    local monthHolidayCount = {}
    if holidays then
        for date in pairs(holidays) do
            local y,m,d = date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
            if y and m and d and tonumber(y) == yYear then
                local month = tonumber(m)
                local day = tonumber(d)
                local dow = os.date("*t", os.time({year = tonumber(y), month = month, day = day, hour = 12, min = 0, sec = 0})).wday - 1
                if dow ~= 0 and dow ~= 6 then
                    monthHolidayCount[month] = (monthHolidayCount[month] or 0) + 1
                end
            end
        end
    end

    for m = 1, 12 do
        local row = math.floor((m - 1) / YV_COLS)
        local col = (m - 1) % YV_COLS
        local mx  = col * YV_CEL_W
        local my  = YV_GRID_Y + row * YV_CEL_H
        drawMini(mx, my, YV_CEL_W, YV_CEL_H, yYear, m, monthHolidayCount[m] or 0)
    end

    if showHints then
        gui.drawButtonHints(BUTTON.exit, BUTTON.selectMonth, BUTTON.left, BUTTON.right)
    else
        gui.drawButtonHints(BUTTON.none, BUTTON.none, BUTTON.none, BUTTON.none)
    end
end

-- ── Status rendering (Error/info) ─────────────────────────
local function renderStatus(msg)
    gui.clear()
    if type(msg) ~= "string" then msg = tostring(msg or "") end
    local y = 170
    for segment in msg:gmatch("[^\n]+") do
        local line = segment
        if #line > 60 then line = line:sub(1, 60) .. "..." end
        gui.drawText(FONTS.jp_ui12, 24, y, line, true)
        y = y + 20
        if y > 740 then break end
    end
    gui.drawButtonHints(BUTTON.exit, BUTTON.none, BUTTON.none, BUTTON.none)
    gui.refresh(REFRESH_FAST)
end

-- ── Input: month view ──────────────────────────────
local function handleMonthView()
    if input.wasPressed(KEY.back) then
        sys.exit()
    end

    local changed = false

    if input.wasPressed(KEY.left) then
        -- Previous month (with year rollover)
        viewMonth = viewMonth - 1
        if viewMonth < 1 then
            viewMonth = 12
            switchYear(cycleYear(viewYear, -1))
        end
        saveSettings()
        firstDraw = true
        changed   = true
    elseif input.wasPressed(KEY.right) then
        -- Next month (with year rollover)
        viewMonth = viewMonth + 1
        if viewMonth > 12 then
            viewMonth = 1
            switchYear(cycleYear(viewYear, 1))
        end
        saveSettings()
        firstDraw = true
        changed   = true
    elseif input.wasPressed(KEY.down) then
        showHints = not showHints
        saveSettings()
        changed = true
    elseif input.wasPressed(KEY.confirm) then
        -- Confirm also switches to year view
        selMonth  = viewMonth
        viewMode  = "year"
        saveSettings()
        firstDraw = true
        changed   = true
    elseif input.wasPressed(KEY.up) then
        if startDow == 1 then
            startDow = 0
        elseif startDow == 0 then
            startDow = 6
        else
            startDow = 1
        end
        saveSettings()
        changed = true
    end

    if changed then needsRedraw = true end
end

-- ── Input: year view ───────────────────────────────
local function handleYearView()
    if input.wasPressed(KEY.back) then
        sys.exit()
    end

    local changed = false

    if input.wasPressed(KEY.left) then
        -- Previous month in year view (wrap to previous year if needed)
        selMonth = selMonth - 1
        if selMonth < 1 then
            selMonth = 12
            viewYear = viewYear - 1
            switchYear(viewYear)
        end
        saveSettings()
        changed = true
    elseif input.wasPressed(KEY.right) then
        -- Next month in year view (wrap to next year if needed)
        selMonth = selMonth + 1
        if selMonth > 12 then
            selMonth = 1
            viewYear = viewYear + 1
            switchYear(viewYear)
        end
        saveSettings()
        changed = true
    elseif input.wasPressed(KEY.down) then
        showHints = not showHints
        saveSettings()
        changed = true
    elseif input.wasPressed(KEY.up) then
        if startDow == 1 then
            startDow = 0
        elseif startDow == 0 then
            startDow = 6
        else
            startDow = 1
        end
        saveSettings()
        changed = true
    elseif input.wasPressed(KEY.confirm) then
        -- Jump to selected month in month view
        viewMonth = selMonth
        viewMode  = "month"
        saveSettings()
        firstDraw = true
        changed   = true
    end

    if changed then needsRedraw = true end
end

-- ── Plugin entry points ────────────────────────────
function init()
    local stored = loadSettings()
    if stored ~= nil and stored.startDow then
        startDow = stored.startDow
    else
        startDow = 1
    end
    if stored ~= nil and stored.viewMode == "year" then
        viewMode = "year"
    else
        viewMode = "month"
    end
    local nowYear = getCurrentYear()
    viewYear        = stored ~= nil and stored.viewYear or nowYear
    viewMonth       = stored ~= nil and stored.viewMonth or 1
    selMonth        = stored ~= nil and stored.selMonth or viewMonth
    showHints       = stored ~= nil and stored.showHints or true
    showQuarter     = stored ~= nil and stored.showQuarter or true
    showHolidayCount = stored ~= nil and stored.showHolidayCount or true
    showWeekNumber  = stored ~= nil and stored.showWeekNumber or true
    holidays        = {}
    state           = "display"
    needsRedraw     = true
    firstDraw       = true
    skipFrames      = 3

    local ok, err = pcall(function()
        -- 1. Try hardware RTC
        if not detectDate() then
            if not loadCachedDate() then
                curYear  = getCurrentYear()
                curMonth = 1
                curDay   = 1
            end
        end
        if not curYear or not curMonth or not curDay then
            curYear  = getCurrentYear()
            curMonth = curMonth or 1
            curDay   = curDay or 1
        end

        viewYear  = curYear or getCurrentYear()
        viewMonth = curMonth or 1
        selMonth  = viewMonth

        -- 埋め込み祝日データを読み込む
        local csvholidays = loadHolidayCsv(viewYear)
        if csvholidays then
            holidays = csvholidays
        else
            holidays = {}
            errorMsg = STR.HOLIDAY_DATA_FAIL
            state = "error"
        end
    end)

    if not ok then
        curYear  = getCurrentYear()
        curMonth = 1
        curDay   = 1
        viewYear = curYear
        viewMonth = curMonth
        selMonth = viewMonth
        holidays = {}
        errorMsg = STR.INITIALIZATION_FAILED_PREFIX .. tostring(err)
        state = "error"
    end
end

function draw()
    if input.wasPressed(KEY.back) then
        sys.exit()
        return
    end

    -- no confirm reload here; confirm is handled in view handlers

    if state == "display" then
        if skipFrames and skipFrames > 0 then
            skipFrames = skipFrames - 1
        else
            if viewMode == "month" then
                handleMonthView()
            else
                handleYearView()
            end
        end
    end

    if not needsRedraw then return end
    needsRedraw = false

    if state == "display" then
        if viewMode == "month" then
            drawMonthView()
        else
            drawYearView()
        end
        if firstDraw then
            gui.refresh(REFRESH_FULL)
            firstDraw = false
        else
            gui.refresh(REFRESH_FAST)
        end
    elseif state == "error" then
        renderStatus(errorMsg or STR.GENERIC_ERROR)
    end
end
