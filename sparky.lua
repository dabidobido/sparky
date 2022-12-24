require 'pack'
require 'lists'
require 'strings'
res = require 'resources'
config = require 'config'

_addon.name = 'Sparky'
_addon.version = '1.0.3'
_addon.author = 'Byrth, Dabidobido'
_addon.commands = {'sparky'}

item = 12385 -- Default to Acheron's Shield
number_to_sell = nil
current_sparks = nil
print_code = false
start_buying = false
appraise = false
start_selling = true
last_seq = nil
auto_purge = false

option_strings = {
    [12385]={str=string.char(9,0,0x29,0),cost=2755}, -- Acheron's Shield
    [12302]={str=string.char(8,0,0x24,0),cost=473}, -- Darksteel Buckler
    [16834]={str=string.char(4,0,0xE,0),cost=60}, -- Brass Spear
    [17081]={str=string.char(4,0,0x15,0),cost=60}, -- Brass Rod
    [16407]={str=string.char(4,0,0,0),cost=60}, -- Brass Baghnakhs
    [12680]={str=string.char(5,0,0x1F,0),cost=141}, -- Chain Mittens
    [12936]={str=string.char(5,0,0x21,0),cost=129}, -- Greaves
    [12299]={str=string.char(3,0,0x3F,0),cost=50,id=12299}, -- Aspis
    [16704]={str=string.char(3,0,0xC,0),cost=50}, -- Butterfly Axe
    [16390]={str=string.char(3,0,0x1,0),cost=50}, -- Bronze Knuckles
    [16900]={str=string.char(3,0,0x12,0),cost=50}, -- Wakizashi
    [16960]={str=string.char(4,0,0x12,0),cost=68}, -- Uchigatana
    [16419]={str=string.char(7,0,2,0),cost=416}, -- Patas
    [16406]={str=string.char(5,0,1,0),cost=144}, -- Baghnakhs
    [16470]={str=string.char(9,0,2,0),cost=300}, -- Gully
    [13871]={str=string.char(6,0,0x43,0),cost=302}, -- Iron Visor
    [13783]={str=string.char(6,0,0x44,0),cost=464}, -- Iron Scale Mail
    [12938]={str=string.char(7,0,0x32,0),cost=322}, -- Sollerets
    [16644]={str=string.char(6,0,0x0D,0),cost=540}, -- Mythril Axe
	[12834]={str=string.char(4,0,0x2E,0),cost=60}, -- Bone Subligar
	[12414]={str=string.char(5,0,0x32,0),cost=70}, -- Turtle Shield
	[17610]={str=string.char(7,0,0x04,0),cost=90}, -- Bone Knife
	[16794]={str=string.char(8,0,0x0E,0),cost=200}, -- Bone Scythe
	[17352]={str=string.char(7,0,0x21,0),cost=90}, -- Horn
	[17257]={str=string.char(4,0,0x1D,0),cost=200}, -- Bandit's Gun
	[15315]={str=string.char(5,0,0x26,0),cost=379}, -- Shade Leggings
	[17612]={str=string.char(8,0,0x03,0),cost=200}, -- Beetle Knife
	[12710]={str=string.char(4,0,0x2D,0),cost=60}, -- Bone Mittens
	[16642]={str=string.char(4,0,0x09,0),cost=93}, -- Bone Axe
	[17062]={str=string.char(7,0,0x17,0),cost=112}, -- Bone Rod
	[17259]={str=string.char(5,0,0x17,0),cost=432}, -- Pirate's Gun
	[12582]={str=string.char(4,0,0x2C,0),cost=60}, -- Bone Harness
	[12454]={str=string.char(4,0,0x2B,0),cost=65}, -- Bone Mask
	[12834]={str=string.char(4,0,0x2E,0),cost=60}, -- Bone Subligar
	[15315]={str=string.char(5,0,0x26,0),cost=379}, -- Shade Leggings
	[16649]={str=string.char(4,0,0x0A,0),cost=60}, -- Bone Pick
	[17361]={str=string.char(8,0,0x1E,0),cost=200}, -- Crumhorn
	[16422]={str=string.char(8,0,0x02,0),cost=362}, -- Tigerfangs
	[12966]={str=string.char(4,0,0x2F,0),cost=60}, -- Bone Leggings
}

defaults = {}
defaults.purge_items = L{"",""}

settings = config.load(defaults)

sparks_npcs = L{'Eternal Flame','Rolandienne','Isakoth','Fhelm Jobeizat'}

items_to_sell = L{}
appraised = S{}
buying = nil

function get_item_from_command(command_string)
	if tonumber(command_string) and res.items[tonumber(command_string)] then
		return tonumber(command_string)
	else
		counter = 0
		for i,v in pairs(res.items) do
			if v.en and v.en:lower() == command_string then
				return i
			end
			counter = counter + 1
			if counter%1000 == 0 then
				coroutine.sleep(0.04) -- Sleep 1 frame every 1000 items searched to avoid lagging people out
			end
		end
	end
	print("Couldn't find " .. command_string .. " in resources")
	return nil
end

windower.register_event('outgoing chunk',function(id,org,mod,inj)
    local seq = org:unpack('H',3)
    if not last_seq then last_seq = seq end
    if not inj and seq ~= last_seq then
        last_seq = seq
        if start_selling and items_to_sell:length()>0 then
            local item_tab = items_to_sell:remove(1)
            windower.packets.inject_outgoing(0x84,string.char(0x84,0x06,0,0)..'I':pack(item_tab.count)..'H':pack(item_tab.id)..string.char(item_tab.slot,0))
            windower.packets.inject_outgoing(0x85,string.char(0x85,0x04,0,0)..'I':pack(1))
        elseif buying then
            buy_one()
        end
    end
    if not inj and id == 0x05B then
        local name = (windower.ffxi.get_mob_by_id(org:unpack('I',5)) or {}).name
        if name == 'Ardrick' then
            return org:sub(1,8)..string.char(1,0,60,0)..org:sub(13)
        end
    end
end)

windower.register_event('addon command',function(...)
    local commands = {...}
    local first = table.remove(commands,1):lower()
    if first then
        if first == 'buy' then
            local second = table.remove(commands,1)
            second = tonumber(second)
            for i,v in pairs(windower.ffxi.get_mob_array()) do
                if v.name and sparks_npcs:contains(v.name) and math.sqrt(v.distance)<10 and windower.ffxi.get_player().status == 0 then
                    windower.packets.inject_outgoing(0x1A,string.char(0x1A,0xE,0,0)..'IHHHHIII':pack(v.id,v.index,0,0,0,0,0,0))
                    start_buying = tonumber(second) and second or true
                    break
                end
            end
        elseif first == 'sell' then
            local second = table.remove(commands,1)
            if tonumber(second) then
                number_to_sell = tonumber(second)
            else
                number_to_sell = nil
            end
            if not res.items[item] then
                print('Sparky: Item cannot be sold because id is not in the resources')
            elseif res.items[item].flags['No NPC Sale'] then
                print('Sparky: Item cannot be sold because it is unsellable')
            else
                items_to_sell = L{}
                local inv = windower.ffxi.get_items(0)
                for i,v in ipairs(inv) do
                    if v.id and v.id == item then
                        items_to_sell:append(v)
                        if number_to_sell and number_to_sell == items_to_sell:length() then break end
                    end
                end
                if items_to_sell:length() > 0 then
                    windower.packets.inject_outgoing(0x84,string.char(0x84,0x06,0,0)..'I':pack(items_to_sell[1].count)..'H':pack(item)..string.char(items_to_sell[1].slot,0))
                    appraise = true
                end
            end
        elseif first == 'item' then
            local pot_item = table.concat(commands,' '):lower()
			local item_id = get_item_from_command(pot_item)
			if item_id then
				item = item_id
				print('Sparky: Item is now '..res.items[item].en)
			end
        elseif first == 'purge' then
			local second = table.remove(commands,1)
			if second then
				second = second:lower()
				if second == 'add' or second == 'remove' then
					local pot_item = table.concat(commands,' '):lower()
					local item_id = get_item_from_command(pot_item)
					if item_id then
						if second == 'add' then
							if settings.purge_items:contains(tostring(item_id)) then
								print("Item " .. item_id .. " already in purge list")
							else
								settings.purge_items:append(tostring(item_id))
								print("Item " .. item_id .. " added to purge list")
								settings:save()
							end
						elseif second == 'remove' then
							local item_as_string = tostring(item_id)
							for k, v in pairs(settings.purge_items) do
								if v == item_as_string then
									settings.purge_items:remove(k)
									print("Item " .. item_id .. " removed from purge list")
									settings:save()
									return
								end
							end
							print('Item ' .. item_id .. ' not found in purge list')
						end
					end
				end
            elseif not res.items[item] then
                print('Sparky: Item cannot be sold because id is not in the resources')
            elseif res.items[item].flags['No NPC Sale'] then
                print('Sparky: Item cannot be sold because it is unsellable')
            else
                items_to_sell = L{}
                appraised = S{}
                local inv = windower.ffxi.get_items(0)
                for i,v in ipairs(inv) do
                    if v.id and settings.purge_items:contains(tostring(v.id)) then
                        items_to_sell:append(v)
                        if number_to_sell and number_to_sell == items_to_sell:length() then break end
                    end
                end

                for _,v in ipairs(items_to_sell) do
                    if not appraised:contains(v.id) then
                        windower.packets.inject_outgoing(0x84,string.char(0x84,0x06,0,0)..'I':pack(v.count)..'H':pack(v.id)..string.char(v.slot,0))
                        appraised:append(v.id)
                    end
                end
            end
        elseif first == 'print' then
            print_code = not print_code
            print('Sparky: Print is now set to '..tostring(print_code))
		elseif first == 'autopurge' then
			auto_purge = not auto_purge
			print("Auto Purge: " .. tostring(auto_purge))
        end
    end
end)

function buy_one()
    if buying and buying.number > 0 then
        buying.number = buying.number - 1
        windower.packets.inject_outgoing(0x5B,buying.buy_packet)
    end
    if buying and buying.number <= 0 then
        windower.packets.inject_outgoing(0x5B,buying.end_packet)
        buying = nil
    end
end

windower.register_event('incoming chunk',function(id,org)
    if id == 0x034 and sparks_npcs:contains(windower.ffxi.get_mob_by_id(org:unpack('I',5)).name) and option_strings[item] and start_buying then
        local current_sparks = org:unpack('I',13)
        local inv_stats = windower.ffxi.get_bag_info(0)
        buying = {
            number = math.min(math.floor(current_sparks/option_strings[item].cost),inv_stats.max - inv_stats.count),
            buy_packet = string.char(0x5B,0xA,0,0)..org:sub(5,8)..option_strings[item].str..org:sub(0x29,0x2A)..string.char(1,0)..org:sub(0x2B,0x2E),
            end_packet = string.char(0x5B,0xA,0,0)..org:sub(5,8)..string.char(1,0,0,0)..org:sub(0x29,0x2A)..string.char(0,0)..org:sub(0x2B,0x2E)
            }
        if type(start_buying) == 'number' then
            buying.number = math.min(buying.number,start_buying)
        end
        buy_one()
        start_buying = false
        return true
    elseif id == 0x03D and appraise then
        appraise = false
        start_selling = true
    elseif id == 0x00A then
        appraised = S{}
    end
end)

windower.register_event('add item', function(bag, index, id, count)
	if auto_purge and bag == 0 then
		local inv = windower.ffxi.get_bag_info(0)
		if inv.max - inv.count <= 5 then
			windower.send_command('sparky purge')
		end
	end
end)