function merge_table(tbl1, tbl2)
	for k,v in pairs(tbl2) do
		if type(v) == 'table' and tbl1[k] then
			merge_table(tbl1[k], v)
		else
			tbl1[k] = v
		end
	end
end

function dir(t) 
	local res = ""

	for i,x in pairs(t) do
		res = res .. tostring(i) .. ": " .. tostring(x) .. "\n"
	end 	

	return res:sub(0, #res-1)
end 

function print_table(t)
	print( dir(t) )
end

function ShuffleTable(someTable, randFunc)
	if not randFunc then
		randFunc = RandomInt
	end
	
	for idx, x in pairs(someTable) do
		local i = randFunc(1, #someTable)

		if i ~= idx then
			local temp = x
			someTable[idx] = someTable[i]
			someTable[i] = temp
		end
	end

	return someTable 
end

local function _format_force_print( ... )
	local text = ""

	local nArgs = select("#", ...)

	for i = 1, nArgs do
		text = text .. " " .. tostring( select(i, ...) )
	end

	return text
end

function force_print( ... )
	local text = _format_force_print( ... )

	CustomGameEventManager:Send_ServerToAllClients("DebugMessage", { msg = text })
end

function force_print_player( player, ... )
	local text = _format_force_print( ... )

	CustomGameEventManager:Send_ServerToPlayer(player, "DebugMessage", { msg = text })
end

local _unpack = unpack or table.unpack

local function _err_handler(err)
    err = tostring(err)
	return debug.traceback(err, 2)
end

function SafeCall(func, ...)
    local ok, res = xpcall(func, _err_handler, ...)

    if not ok then
        print("========== VSCRIPT ERROR ==========")
        print(res) -- res уже traceback string
        print("===================================")
        return nil
    end

    return res
end

function Safe_Wrap(mt, name)
    local func = Dynamic_Wrap(mt, name)
    return function(...)
        return SafeCall(func, ...)
    end
end

function table_contains(tbl, x)
	local found = false
	for _, v in pairs(tbl) do
		if v == x then
			found = true
		end
	end
	return found
end
