Config = Config or {}
if not Config.Framework then
    Config = exports['Song_AutoPay']:GetConfig()
end

local framework = Config.Framework
local isQB = framework == 'qb'
local isESX = framework == 'esx'

if isQB then
    local QBCore = exports['qb-core']:GetCoreObject()
elseif isESX then
    local ESX = exports["es_extended"]:getSharedObject()
else
    print("Error: Supported frame type not detected. Please set the Config.Framework to 'qb' or 'esx' in config.lua.")
    return
end

local BillingSystem = nil
if Config.BillingSystem == 'okokbilling' then
    BillingSystem = require 'billing.okokbilling'
elseif Config.BillingSystem == 'esx' then
    BillingSystem = require 'billing.esx'
else
    print("Error: A supported billing system was not detected. Please set the Config.BillingSystem to 'okokbilling' or 'esx' in config.lua.")
    return
end

local function GetPlayer(identifier)
    if isQB then
        return QBCore.Functions.GetPlayerByCitizenId(identifier)
    elseif isESX then
        return ESX.GetPlayerFromIdentifier(identifier)
    end
end

local function RemoveMoney(player, amount, reason)
    if isQB then
        local cashBalance = player.PlayerData.money['cash']
        local bankBalance = player.PlayerData.money['bank']
        if Config.Priority == 'cash' then
            if cashBalance >= amount then
                player.Functions.RemoveMoney('cash', amount, reason)
                return true, 'cash'
            elseif bankBalance >= amount then
                player.Functions.RemoveMoney('bank', amount, reason)
                return true, 'bank'
            end
        else
            if bankBalance >= amount then
                player.Functions.RemoveMoney('bank', amount, reason)
                return true, 'bank'
            elseif cashBalance >= amount then
                player.Functions.RemoveMoney('cash', amount, reason)
                return true, 'cash'
            end
        end
    elseif isESX then
        local cashBalance = player.getMoney()
        local bankBalance = player.getAccount('bank').money
        if Config.Priority == 'cash' then
            if cashBalance >= amount then
                player.removeMoney(amount)
                return true, 'cash'
            elseif bankBalance >= amount then
                player.removeAccountMoney('bank', amount)
                return true, 'bank'
            end
        else
            if bankBalance >= amount then
                player.removeAccountMoney('bank', amount)
                return true, 'bank'
            elseif cashBalance >= amount then
                player.removeMoney(amount)
                return true, 'cash'
            end
        end
    end
    return false, nil
end

local function AutomaticBilling()
    local unpaidBills = BillingSystem.GetUnpaidBills()
    if unpaidBills and #unpaidBills > 0 then
        for _, bill in ipairs(unpaidBills) do
            local receiverIdentifier = bill.receiver_identifier or bill.identifier
            local totalAmount = bill.invoice_value or bill.amount
            local billId = bill.id
            local reason = bill.item or bill.label

            local Player = GetPlayer(receiverIdentifier)
            if Player then
                local success, moneyType = RemoveMoney(Player, totalAmount, reason)
                if success then
                    print(('Player %s has paid bill %d from %s (amount: %s%d) for reason: %s.'):format(Player.getName() or Player.PlayerData.name, moneyType, billId, Config.CurrencySymbol, totalAmount, reason))
                else
                    print(('Player %s does not have enough cash and bank balance to pay the bill %d (amount: %s%d) for reason: %s.'):format(Player.getName() or Player.PlayerData.name, billId, Config.CurrencySymbol, totalAmount, reason))
                    goto continue
                end

                BillingSystem.MarkBillAsPaid(billId)
                print(('Bill %d has been marked as paid.'):format(billId))

                ::continue::
            else
                if Config.AllowOfflinePayment then
                    print(('Player %s is not online, but offline deductions are allowed. Bill %d (amount: %s%d) and reason: %s will be processed later.'):format(receiverIdentifier, billId, Config.CurrencySymbol, totalAmount, reason))
                else
                    print(('Player %s is not online. Bill %d (amount: %s%d) and reason: %s will be processed later.'):format(receiverIdentifier, billId, Config.CurrencySymbol, totalAmount, reason))
                end
            end
        end
    else
        print("Unpaid bills were not found.")
    end
end

Citizen.CreateThread(function()
    while true do
        AutomaticBilling()
        Citizen.Wait(Config.BillInterval)
    end
end)