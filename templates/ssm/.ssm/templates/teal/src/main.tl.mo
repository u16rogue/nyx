{{! THIS WAS WRITTEN BY A CLANKER }}
local utils = require("utils")

local function main(args: {string}): integer
    print(utils.greet("{{subproject_name}}"))
    for i, value in ipairs(args) do
        print(string.format("arg %d: %s", i, value))
    end
    return 0
end

os.exit(main({ ... }))
