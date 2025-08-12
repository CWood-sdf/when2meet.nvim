---@module 'banana.instance'

local hashWidth = 9

local numberMode = false
local minPct = 0
---idk
---@param hash Banana.Ast
---@param time When2Meet.JsonInfo.Time
---@param num number
---@param den number
local function setHashContent(hash, time, num, den)
    local clear = string.rep(" ", hashWidth)
    if den == 0 then
        hash:setTextContent(clear)
        return
    end
    if num / den * 100 < minPct then
        hash:setTextContent(clear)
        return
    end
    if numberMode then
        local str = #time.available .. ""
        hash:setTextContent(str .. string.rep(" ", hashWidth - #str))
    else
        hash:setTextContent(string.rep("#", hashWidth))
    end
end

local lastHash = nil

---@param hash Banana.Ast
---@param document Banana.Instance
---@param time When2Meet.JsonInfo.Time
---@param json When2Meet.JsonInfo
local function updateHash(hash, document, time, json)
    if not hash:isHovering() then
        return
    end
    if hash == lastHash then
        return
    end
    lastHash = hash
    local start = vim.uv.hrtime()
    local peopleavail = document:getElementById("peopleavail")
    local peopleunavail = document:getElementById("peopleunavail")
    peopleavail:removeChildren()
    peopleunavail:removeChildren()
    local a = document:createElement('div')
    a:addClass("header")
    a:setTextContent("Available")
    peopleavail:appendChild(a)
    for _, name in ipairs(time.available) do
        local row = document:createElement("div")
        row:setTextContent(name.name)
        peopleavail:appendChild(row)
    end
    local u = document:createElement('div')
    u:addClass("header")
    u:setTextContent("Unavailable")
    peopleunavail:appendChild(u)
    for _, name in ipairs(json.names) do
        for _, n in ipairs(time.available) do
            if n.name == name.name then
                goto continue
            end
        end
        local row = document:createElement("div")
        row:setTextContent(name.name)
        peopleunavail:appendChild(row)
        ::continue::
    end

    local d = document:getElementById("date")
    if json.tp == "general" then
        d:setTextContent(vim.fn.strftime("%a %I:%M %p", time.time))
    else
        d:setTextContent(vim.fn.strftime("%b %d %Y %I:%M %p", time.time))
    end

    local count = document:getElementById("availcount")
    count:setTextContent(#time.available .. " / " .. #json.names .. " Available")

    vim.print((vim.uv.hrtime() - start) / 1000000 .. "ms")
end

local function filterPeople(json, people)
    for _, v in ipairs(people) do
        if v:getAttribute("active") == "true" then
            goto continue
        end
        local name = v:getAttribute("name")

        for j, n in ipairs(json.names) do
            if n.name == name then
                table.remove(json.names, j)
                break
            end
        end
        -- vim.print("Removing '" .. name .. "'\n")
        for _, timeslot in ipairs(json.times) do
            for k, nn in ipairs(timeslot.available) do
                if nn.name == name then
                    table.remove(timeslot.available, k)
                    -- vim.print("REMOVED\n")
                    break
                end
            end
        end
        -- vim.print(json.times)

        ::continue::
    end
end

---@param document Banana.Instance
---@param json When2Meet.JsonInfo
local function updateDocument(document, json)
    local els = document:getElementsByClassName("count")
    for _, v in ipairs(els) do
        v:setTextContent(#json.names .. "")
    end
    local colors = document:getElementById("colors")
    colors:removeChildren()
    ---@type Banana.Ast[]
    local people = {}
    if #json.names ~= 0 then
        for i = 0, #json.names do
            local color = math.floor(255 * i / #json.names)
            local redblue = 255 - color
            local colorNum = redblue * 256 * 256 + 255 * 256 + redblue
            if colorNum > 0xffffff then
                colorNum = colorNum % 0xffffff
            end
            local colorStr = string.format("#%6x", colorNum)
            colorStr = colorStr:gsub(" ", "0", 20)
            local el = document:createElement("span")
            el:setStyle("hl-fg: " .. colorStr .. ";")
            el:setTextContent("#")
            colors:appendChild(el)
        end
    end
    local list = document:getElementById("peoplelist")
    list:removeChildren()
    for _, jsonName in ipairs(json.oldNames) do
        local person = document:createElement("div")
        local isFound = false
        for _, v in ipairs(json.names) do
            if v.id == jsonName.id then
                isFound = true
                break
            end
        end
        if isFound then
            person:setTextContent(
                "[x] " .. jsonName.name)
            person:setAttribute("active", "true")
        else
            person:setTextContent(
                "[ ] " .. jsonName.name)
            person:setAttribute("active", "false")
        end
        person:setAttribute("name", jsonName.name)
        person:attachRemap("n", "<CR>", { "hover" }, function()
            if person:getAttribute("active") == "true" then
                person:setAttribute("active", "false")
            else
                person:setAttribute("active", "true")
            end
            json.names = vim.deepcopy(json.oldNames)
            json.times = vim.deepcopy(json.oldTimes)

            filterPeople(json, people)

            updateDocument(document, json)
        end, {})
        table.insert(people, person)
        list:appendChild(person)
    end
    list:attachRemap("n", "<C-l>", {}, function()
        local changed = false
        for _, person in ipairs(people) do
            if person:getAttribute("active") == "false" then
                changed = true
                person:setAttribute("active", "true")
            end
        end
        if changed then
            json.names = vim.deepcopy(json.oldNames)
            json.times = vim.deepcopy(json.oldTimes)
            filterPeople(json, people)
            updateDocument(document, json)
        end
    end, {})
    list:attachRemap("n", "<C-e>", {}, function()
        local str = vim.fn.input("Filter: ") or ""
        local changed = false
        for _, person in ipairs(people) do
            if person:getAttribute("active") == "true" then
                local match = person:getAttribute("name"):match(str)
                if match ~= nil then
                    changed = true
                    person:setAttribute("active", "false")
                end
            end
        end
        if changed then
            filterPeople(json, people)
            updateDocument(document, json)
        end
    end, {})
    list:attachRemap("n", "<C-f>", {}, function()
        local str = vim.fn.input("Filter: ") or ""
        local changed = false
        for _, person in ipairs(people) do
            if person:getAttribute("active") == "true" then
                local match = person:getAttribute("name"):match(str)
                if match == nil then
                    changed = true
                    person:setAttribute("active", "false")
                end
            end
        end
        if changed then
            filterPeople(json, people)
            updateDocument(document, json)
        end
    end, {})
    ---@type { [string]: When2Meet.JsonInfo.Time[] }
    local days = {}
    local hashEls = {}
    -- have to skip every other iteration bc banana changes the document
    -- so otherwise, this is called ad infinitum
    local skip2 = false
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = 0,
        group = vim.api.nvim_create_augroup("when2meetcursor1", { clear = true }),
        callback = function()
            if skip2 then
                skip2 = false
                return
            end
            for _, el in ipairs(hashEls) do
                if el.hash:isHovering() then
                    updateHash(el.hash, document, el.time, el.json)
                    skip2 = true
                    break
                end
            end
        end
    })
    local order = {}
    for _, v in ipairs(json.times) do
        local dayfmt = "%Y %m %d"
        local dayid = vim.fn.strptime(dayfmt, vim.fn.strftime(dayfmt, v.time)) .. ""
        if days[dayid] == nil then
            table.insert(order, dayid)
        end
        days[dayid] = days[dayid] or {}
        table.insert(days[dayid], v)
    end
    local avail = document:getElementById("available")
    avail:removeChildren()
    local firstIter = true
    local pctTimeout = 0
    local timeBase = nil
    for _, od in ipairs(order) do
        local k = od
        local v = days[k]
        -- for k, v in pairs(days) do
        if firstIter then
            local el = document:createElement("div")
            if json.tp == "general" then
                el:setStyleValue("padding-top", "1ch")
            else
                el:setStyleValue("padding-top", "2ch")
            end
            for i, time in ipairs(v) do
                local div = document:createElement("div")
                local str = vim.fn.strftime("%I:%M %p", time.time)
                if vim.fn.strftime("%M", time.time) == "00" then
                    timeBase = timeBase or i
                    div:setTextContent(str)
                else
                    div:setTextContent(" ")
                end
                el:appendChild(div)
            end
            avail:appendChild(el)
            firstIter = false
        end
        local el = document:createElement("div")
        if json.tp == "exact" then
            local date = document:createElement("div")
            date:setTextContent(vim.fn.strftime("%b %d", tonumber(k)))
            el:appendChild(date)
            date:addClass("padded")
        end
        local day = document:createElement("div")
        day:setStyleValue("hl-bold", "true")
        day:setTextContent(vim.fn.strftime("%a", tonumber(k)))
        day:addClass("padded")
        el:appendChild(day)
        for i, time in ipairs(v) do
            local color = math.floor(255 * #time.available / #json.names)
            local redblue = 255 - color
            local colorNum = redblue * 256 * 256 + 255 * 256 + redblue
            if colorNum > 0xffffff then
                colorNum = colorNum % 0xffffff
            end
            local colorStr = string.format("#%6x", colorNum)
            colorStr = colorStr:gsub(" ", "0", 20)
            if #colorStr > 7 then
                colorStr = string.sub(colorStr, #colorStr - 5, #colorStr)
                colorStr = "#" .. colorStr
            end
            local hash = document:createElement("div")
            setHashContent(hash, time, #time.available, #json.names)
            hash:attachRemap("n", "n", {}, function()
                numberMode = not numberMode
                for _, h in ipairs(hashEls) do
                    setHashContent(h.hash, h.time, #h.time.available, #json.names)
                end
            end, {})
            hash:attachRemap("n", "c", {}, function()
                if vim.uv.hrtime() - pctTimeout > 100 * 1000 * 1000 then
                    local pct = vim.fn.input("Gimme a pct: ")
                    minPct = tonumber(pct) or error("no pct given :(")
                    pctTimeout = vim.uv.hrtime()
                end

                setHashContent(hash, time, #time.available, #json.names)
                document:bubbleEvent()
            end, {})
            hash:setStyleValue("hl-fg", colorStr)
            hash:addClass("hash")
            hash:attachRemap("n", "<CR>", { "hover" }, function()
                updateHash(hash, document, time, json)
            end, {})
            if (i - timeBase + 1) % 4 == 0 and i ~= #v then
                hash:addClass("underline")
            end
            table.insert(hashEls, {
                hash = hash,
                time = time,
                json = json
            })
            el:appendChild(hash)
        end
        avail:appendChild(el)
    end
end

---@param document Banana.Instance
return function(document)
    document:getElementById("header"):attachRemap("n", "<C-r>", {}, function()
        local url = vim.fn.input("Gimme a when2meet url: ")
        while url == nil or url == "" do
            print("I cant use this, try again")
            url = vim.fn.input("Gimme a when2meet url: ")
        end
        require("when2meet").curl(url, vim.schedule_wrap(function(json)
            json.oldNames = vim.deepcopy(json.names)
            json.oldTimes = vim.deepcopy(json.times)
            document:getElementById("title"):setInnerNml("<span>" .. json.title.value .. "</span>")
            updateDocument(document, json)
        end))
    end, {})
    local url = vim.fn.input("Gimme a when2meet url: ")
    while url == nil or url == "" do
        print("I cant use this, try again")
        url = vim.fn.input("Gimme a when2meet url: ")
    end
    require("when2meet").curl(url, vim.schedule_wrap(function(json)
        json.oldNames = vim.deepcopy(json.names)
        json.oldTimes = vim.deepcopy(json.times)
        document:getElementById("title"):setInnerNml("<span>" .. json.title.value .. "</span>")
        updateDocument(document, json)
    end))
end
