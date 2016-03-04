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

local function insert(t, s, v, offered, required, toReturn, returnslot, resultslot)
  local maxPaid = math.floor(offered / required)
  local toTransferMax = maxPaid * required
  local toTransfer = toTransferMax
  for i = mappings.config.currencySlots[1], mappings.config.currencySlots[2] do
    local amt = t.getSlotStackSize(s, i)
    if amt == 0 or t.compareStacks(s, i, mappings.config.tempSlot, true) then
      toTransfer = toTransfer - (t.getSlotMaxStackSize(s, mappings.config.tempSlot) - amt)
      if toTransfer <= 0 then -- enough space for everything
        toTransfer = 0
        break
      end
    end
  end
  local paid = math.floor((toTransferMax - toTransfer) / required)
  if paid <= 0 then
    return "Payment storage slots full"
  end
  toTransferMax = paid * toReturn
  toTransfer = toTransferMax
  for i = mappings.config.stockSlots[1], mappings.config.stockSlots[2] do
    if t.compareStacks(s, i, returnslot, true) then
      toTransfer = toTransfer - t.getSlotStackSize(s, i)
      if toTransfer <= 0 then -- everything can be returned
        toTransfer = 0
        break
      end
    end
  end

  do
    local maxReturned = t.getSlotMaxStackSize(s, returnslot)
    if maxReturned > 0 then
      paid = math.min(paid, math.floor(maxReturned / toReturn))
    end
  end
  paid = math.min(paid, math.floor((toTransferMax - toTransfer) / toReturn))
  if paid <= 0 then
    return "Machine out of stock"
  end
  do
    local max = t.getSlotMaxStackSize(v, resultslot)
    if max > 0 then
      local freespace = max - t.getSlotStackSize(v, resultslot)
      if freespace < toTransferMax then
        paid = math.min(paid, math.floor(freespace / toReturn))
      end
    end
  end
  if paid <= 0 then
    return "payment slot full"
  end

  local spent = paid * required
  t.transferItem(s, v, offered - spent, mappings.config.tempSlot, returnslot) -- move remaining payment back
  for slot = mappings.config.currencySlots[1], mappings.config.currencySlots[2] do
    t.transferItem(s, s, spent, mappings.config.tempSlot, slot)
  end
  toTransferMax = paid * toReturn
  toTransfer = toTransferMax
  for slot = mappings.config.stockSlots[1], mappings.config.stockSlots[2] do -- move purchased items
    if t.compareStacks(s, slot, returnslot, true) then
      local amt = t.getSlotStackSize(s, slot)
      t.transferItem(s, s, toTransfer, slot, mappings.config.tempSlot)
      toTransfer = toTransfer - amt
      if toTransfer <= 0 then -- everything has been returned
        toTransfer = 0
        break
      end
    end
  end
  t.transferItem(s, v, 64, mappings.config.tempSlot, resultslot)
  return toTransferMax - toTransfer, spent
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
        local toReturn = cur.t.getSlotStackSize(cur.s, i)
        local transferred, spent = insert(cur.t, cur.s, cur.v, offered, required, toReturn, i, slot)
        if transferred and type(transferred) == "number" and transferred > 0 then
          print("Transferred " .. transferred .. " item(s) from slot " .. i .. " for " .. spent .. " item(s) at transposer ".. cur.t.address)
        else
          prerr("Failed to transfer payment: ".. transferred .." at transposer " .. cur.t.address)
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
