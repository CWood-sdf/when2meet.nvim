---@module 'banana.instance'

---@param hash Banana.Ast
---@param document Banana.Instance
---@param time When2Meet.JsonInfo.Time
---@param json When2Meet.JsonInfo
local function updateHash(hash, document, time, json)
    if not hash:isHovering() then
        return
    end
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
        row:setTextContent(name)
        peopleavail:appendChild(row)
    end
    local u = document:createElement('div')
    u:addClass("header")
    u:setTextContent("Unavailable")
    peopleunavail:appendChild(u)
    for _, name in ipairs(json.names) do
        for _, n in ipairs(time.available) do
            if n == name.name then
                goto continue
            end
        end
        local row = document:createElement("div")
        row:setTextContent(name.name)
        peopleunavail:appendChild(row)
        ::continue::
    end

    local d = document:getElementById("date")
    d:setTextContent(vim.fn.strftime("%b %d %Y %I:%M %p", time.time))

    local count = document:getElementById("availcount")
    count:setTextContent(#time.available .. " / " .. #json.names .. " Available")
end
---@param document Banana.Instance
return function(document)
    require("when2meet").curl("https://www.when2meet.com/?31518963-z2KUh", function(json)
        local els = document:getElementsByClassName("count")
        for _, v in ipairs(els) do
            v:setTextContent(#json.names .. "")
        end
        local colors = document:getElementById("colors")
        for i = 0, #json.names do
            local color = math.floor(255 * i / #json.names)
            local redblue = 255 - color
            local colorStr = string.format("#%6x", redblue * 256 * 256 + 255 * 256 + redblue)
            colorStr = colorStr:gsub(" ", "0")
            -- vim.print(colorStr)
            local el = document:createElement("span")
            el:setStyle("hl-fg: " .. colorStr .. ";")
            el:setTextContent("#")
            colors:appendChild(el)
        end
        ---@type { [string]: When2Meet.JsonInfo.Time[] }
        local days = {}
        vim.schedule(function()
            local hashEls = {}
            -- have to skip every other iteration bc banana changes the document
            -- so otherwise, this is called ad infinitum
            local skip = false
            vim.api.nvim_create_autocmd("CursorMoved", {
                buffer = 0,
                callback = function()
                    if skip then
                        skip = false
                        return
                    end
                    skip = true
                    for _, el in ipairs(hashEls) do
                        if el.hash:isHovering() then
                            updateHash(el.hash, document, el.time, el.json)
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
            local firstIter = true
            for _, od in ipairs(order) do
                local k = od
                local v = days[k]
                -- for k, v in pairs(days) do
                if firstIter then
                    local el = document:createElement("div")
                    el:setStyleValue("padding-top", "2ch")
                    for _, time in ipairs(v) do
                        local div = document:createElement("div")
                        if vim.fn.strftime("%M", time.time) == "00" then
                            local str = vim.fn.strftime("%I:%M %p", time.time)
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
                local date = document:createElement("div")
                date:setTextContent(vim.fn.strftime("%b %d", tonumber(k)))
                el:appendChild(date)
                date:addClass("padded")
                local day = document:createElement("div")
                day:setStyleValue("hl-bold", "true")
                day:setTextContent(vim.fn.strftime("%a", tonumber(k)))
                day:addClass("padded")
                el:appendChild(day)
                for _, time in ipairs(v) do
                    local color = math.floor(255 * #time.available / #json.names)
                    local redblue = 255 - color
                    local colorStr = string.format("#%6x", redblue * 256 * 256 + 255 * 256 + redblue)
                    colorStr = colorStr:gsub(" ", "0")
                    local hash = document:createElement("div")
                    hash:setTextContent("#########")
                    hash:setStyleValue("hl-fg", colorStr)
                    hash:attachRemap("n", "<CR>", { "hover" }, function()
                        updateHash(hash, document, time, json)
                    end, {})
                    table.insert(hashEls, {
                        hash = hash,
                        time = time,
                        json = json
                    })
                    el:appendChild(hash)
                end
                avail:appendChild(el)
            end
        end)
    end)
end
