local M = {}

---@class When2Meet.JsonInfo.Name
---@field id number
---@field name string

---@class When2Meet.JsonInfo.Time
---@field time number
---@field available string[]

---@class When2Meet.JsonInfo
---@field names When2Meet.JsonInfo.Name[]
---@field times When2Meet.JsonInfo.Time[]

local Opts = {
    jscmd = "node"
}

function M.setup(opts)
    Opts.jscmd = opts.jscmd or Opts.jscmd
end

---@param js string
---@param onDone fun(v: When2Meet.JsonInfo)
function M.nodeit(js, onDone)
    vim.system({
        "node"
    }, {
        text = true, stdin = js,
    }, function(out)
        vim.print(out.stderr)
        onDone(vim.json.decode(out.stdout))
    end)
end

---@param html string
---@param onDone fun(v: When2Meet.JsonInfo)
function M.pup(html, onDone)
    vim.system(
        { "pup", '#MainBody script[type="text/javascript"]:nth-of-type(3) text{}' },
        { text = true, stdin = html },
        function(o)
            local stdout = o.stdout or ""
            local lines = vim.split(stdout, "\n")
            if #lines < 618 then
                print("Js to small :(")
            end
            local newScript = [[
var TimeOfSlot = [];
var AvailableAtSlot = [];
var PeopleNames = [];
var PeopleIDs = [];
            ]]
            for i = 618, #lines do
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
		array.push(peopleMap[id]);
	}
	json.times.push({
		time: TimeOfSlot[i],
		available: array,
	});
}

console.log(JSON.stringify(json));
            ]]
            M.nodeit(newScript, onDone)
        end
    )
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
