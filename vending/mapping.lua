return
{
  {
    t = "4e58dc25-add1-45f5-8054-0963fc5c9552", -- addr of the transposer
    r = "e76", -- addr of the RS IO block. Stubs work just fine.
    s = "east", -- direction of the stock chest
    v = "west", -- direction of the vending chest
  }, --repeat tables like this if you have multiple setups connected to this computer

  -- now the slot config. All inventories must have the same number of slots.
  config = { --default config for Vanilla chests.
    inputSlots = {
      {{1, 4}, 6}, -- slot 1 to 4 are for matching offer specifications, slot 6 to 9 are for matching the required currency (both ranges have the same size).
      --{{10, 13}, 15}, -- Example for another range in case you have a bigger chest type. Slot 10 to 13 are for matching inputs, slot 15 to 18 are for matching the required currency.
    },
    tempSlot = 5, -- slot of the stock inventory the trade item will be temporarily moved to for comparing.
    stockSlots = {10, 18}, -- range of slots of the Stock chest to put stock in. Any stock may be anywhere in this range.
    currencySlots = {19, 27}, -- range of slots of the Stock chest to put payment in. Anything received through trading will land here. Trading will fail if slots are full.
  }
}
