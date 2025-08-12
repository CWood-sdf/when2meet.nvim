local M = {}

---@class When2Meet.JsonInfo.Name
---@field id number
---@field name string

---@class When2Meet.JsonInfo.Time
---@field time number
---@field available When2Meet.JsonInfo.Name[]

---@class When2Meet.JsonInfo
---@field tp "exact"|"general"
---@field title { value: string }
---@field names When2Meet.JsonInfo.Name[]
---@field times When2Meet.JsonInfo.Time[]
---@field oldNames When2Meet.JsonInfo.Name[]
---@field oldTimes When2Meet.JsonInfo.Time[]

local Opts = {
    jscmd = "node"
}

local function tzoffset()
    local d = vim.fn.strftime("%z")
    local sign = d:sub(1, 1)
    local hours = d:sub(2, 3)
    local mins = d:sub(4, 5)
    local time = tonumber(hours) * 3600 + tonumber(mins) * 60
    if sign == "-" then
        time = -time
    end
    return time
end

function M.setup(opts)
    Opts.jscmd = opts.jscmd or Opts.jscmd
end

---@type "exact" | "general"
local useType = "exact"

local title = {
    value = ""
}

---@param js string
---@param onDone fun(v: When2Meet.JsonInfo)
function M.nodeit(js, onDone, onFail)
    vim.system({
        "node"
    }, {
        text = true, stdin = js,
    }, function(out)
        if out.stderr ~= nil and out.stderr ~= "" then
            onFail(out.stderr)
        else
            vim.schedule(function()
                ---@type When2Meet.JsonInfo
                local obj = vim.json.decode(out.stdout)
                obj.tp = useType
                obj.title = title
                if obj.tp == "general" then
                    local offset = tzoffset() - 3600
                    for _, v in ipairs(obj.times) do
                        v.time = v.time - offset
                    end
                end
                onDone(obj)
            end)
        end
    end)
end

---idk
---@param lines string[]
---@param lineStart number
---@return string
function M.fixScript(lines, lineStart)
    local newScript = [[
var TimeOfSlot = [];
var AvailableAtSlot = [];
var PeopleNames = [];
var PeopleIDs = [];
            ]]
    for i = lineStart, #lines do
        newScript = newScript .. "\n" .. lines[i]
    end
    newScript = newScript .. [[
var json = {};
json.names = [];
json.times = [];
var peopleMap = {};
for (var i = 0; i < PeopleNames.length; i++) {
    ]] .. "peopleMap[PeopleIDs[i]] = PeopleNames[i];" .. [[
	json.names.push({
            id: PeopleIDs[i],
            name: PeopleNames[i],
        });
}
for (var i in TimeOfSlot) {
	i = i * 1;
	const v = TimeOfSlot[i];
	var time = new Date(v * 1000);
	var array = [];
	for (const id of AvailableAtSlot[i]) {
		array.push({ name: peopleMap[id], id: id });
	}
	json.times.push({
		time: TimeOfSlot[i],
		available: array,
	});
}

console.log(JSON.stringify(json));
            ]]
    return newScript
end

---@param html string
---@param onDone fun(v: When2Meet.JsonInfo)
function M.pup(html, onDone)
    vim.system(
        { "pup", 'title text{}' },
        { text = true, stdin = html },
        function(o)
            local trail = " - When2meet"
            title.value = o.stdout
            title.value = title.value:sub(1, #title.value - #trail)
        end)
    vim.system(
        { "pup", '#MainBody script[type="text/javascript"]:nth-of-type(3) text{}' },
        { text = true, stdin = html },
        function(o)
            local stdout = o.stdout or ""
            local lines = vim.split(stdout, "\n")
            if #lines < 618 then
                print("Js to small :(")
            end
            local newScript = M.fixScript(lines, 618)
            useType = "exact"
            M.nodeit(newScript, onDone, function()
                newScript = M.fixScript(lines, 607)
                useType = "general"
                M.nodeit(newScript, onDone, function()
                    newScript = M.fixScript(lines, 796)
                    M.nodeit(newScript, onDone, function()
                        print("Failed to run :(")
                    end)
                end)
            end)
        end)
end

---@param link string
---@param onDone fun(v: When2Meet.JsonInfo)
function M.curl(link, onDone)
    vim.system({ "curl", link }, { text = true },
        function(obj)
            M.pup(obj.stdout, onDone)
        end)
end

return M
