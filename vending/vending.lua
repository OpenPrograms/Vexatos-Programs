local component = require("component")
local event = require("event")
local sides = require("sides")

local function prerr(...)
  io.stderr:write(...)
  io.stderr:write("\n")
end

local mappings = {}

do
  print("Parsing mappings...")
  local rawmappings = dofile("mapping.lua")
  mappings.config = rawmappings.config
  for i, t in ipairs(rawmappings) do
    if not t.r then
      prerr("No Redstone IO block specified at index " .. i)
    elseif not component.get(t.r) then
      prerr("No Redstone IO block with address " .. t.r .. "found: at index " .. i)
    elseif not t.t then
      prerr("No Transposer specified at index " .. i)
    elseif not component.get(t.t) then
      prerr("No Transposer with address " .. t.t .. "found: at index " .. i)
    elseif not t.s then
      prerr("No Stock chest direction specified at index " .. i)
    elseif not sides[t.s] then
      prerr("Invalid Stock chest direction '" .. t.s .. "' specified at index " .. i)
    elseif not t.v then
      prerr("No Vending chest direction specified at index " .. i)
    elseif not sides[t.v] then
      prerr("Invalid Vending chest direction '" .. t.v .. "' specified at index " .. i)
    else
      t.s = sides[t.s]
      t.v = sides[t.v]
      local tr = component.proxy(component.get(t.t))
      local sc = tr.getInventorySize(t.s)
      local vc = tr.getInventorySize(t.v)
      local err = false
      for k,v in ipairs(mappings.config.inputSlots) do
        if v[1][2] > sc or v[1][2] > vc or v[2] > sc then
          prerr("Invalid inventory at index " .. i .. ": Stock or Vending inventory size is smaller than the range specified in config (".. k ..").")
          err = true
          break
        end
      end
      if mappings.config.tempSlot > sc then
        prerr("Invalid inventory at index " .. i .. ": Stock inventory size does not have the tempSlot specified in config (".. k ..").")
        err = true
      end
      if not err then
        mappings[component.get(t.r)] = {
          t = tr,
          s = t.s,
          v = t.v
        }
      end
    end
  end
end

local function insert(t, s, v, offered, required, returnslot)
  local maxPaid = math.floor(offered / required)
  local toTransferMax = maxPaid * required
  local toTransfer = toTransferMax
  for i = mappings.config.currencySlots[1], mappings.config.currencySlots[2] do
    local amt = t.getSlotStackSize(s, i)
    if amt == 0 or t.compareStacks(s, i, mappings.config.tempSlot, true) then
      toTransfer = toTransfer - (t.getSlotMaxStackSize(s, mappings.config.tempSlot) - amt)
      if toTransfer <= 0 then
        t.transferItem(s, v, offered - toTransferMax, mappings.config.tempSlot, returnslot) -- move remaining payment back
        for slot = mappings.config.currencySlots[1], i do
          t.transferItem(s, s, toTransferMax, mappings.config.tempSlot, slot)
        end
        return maxPaid
      end
    end
  end
  local paid = math.min(math.floor((toTransferMax - toTransfer) / required), t.getSlotStackSize(s, returnslot))
  if paid <= 0 then
    return false
  end
  local spent = paid * required
  t.transferItem(s, v, offered - spent, mappings.config.tempSlot, returnslot) -- move remaining payment back
  for slot = mappings.config.currencySlots[1], mappings.config.currencySlots[2] do
    t.transferItem(s, s, spent, mappings.config.tempSlot, slot)
  end
  return paid
end

local function doTrade(addr)
  local cur = mappings[addr]
  for _,v in ipairs(mappings.config.inputSlots) do
    for i = v[1][1], v[1][2] do
      cur.t.transferItem(cur.v, cur.s, 64, i, mappings.config.tempSlot)
      local slot = v[2] + (i - v[1][1])
      local required = cur.t.getSlotStackSize(cur.s, slot)
      local offered = cur.t.getSlotStackSize(cur.s, mappings.config.tempSlot)
      if offered <= 0 or required <= 0 then
        -- nothing to trade here
      elseif cur.t.compareStacks(cur.s, slot, mappings.config.tempSlot, true)
        and offered >= required then
        -- we have sufficient payment.
        local paid = insert(cur.t, cur.s, cur.v, offered, required, i)
        if paid and paid > 0 then
          print("Transferred " .. paid .. " item(s) from slot " .. i .. " for " .. required .. " item(s) at transposer ".. cur.t.address)
          cur.t.transferItem(cur.s, cur.v, paid, i, slot) -- move purchased items
        else
          prerr("Failed to transfer payment: Payment storage slots full or machine out of stock at transposer " .. cur.t.address)
          cur.t.transferItem(cur.s, cur.v, 64, mappings.config.tempSlot, i)
        end
      else
        prerr("Failed to transfer payment: Invalid payment at transposer " .. cur.t.address)
        cur.t.transferItem(cur.s, cur.v, 64, mappings.config.tempSlot, i)
      end
    end
  end
end

print("Running. Press Ctrl+Alt+C to quit.")
while true do
  local e, addr, old, new = event.pull("redstone_changed")
  if new > 0 and mappings[addr] then
    doTrade(addr)
  end
end
