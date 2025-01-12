If you are Chinese, please copy the following to server.lua

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
    print("错误：未检测到支持的框架类型。请在 config.lua 中设置 Config.Framework 为 'qb' 或 'esx'。")
    return
end

local BillingSystem = nil
if Config.BillingSystem == 'okokbilling' then
    BillingSystem = require 'billing_systems.okokbilling'
elseif Config.BillingSystem == 'esx' then
    BillingSystem = require 'billing_systems.esx'
else
    print("错误：未检测到支持的账单系统。请在 config.lua 中设置 Config.BillingSystem 为 'okokbilling' 或 'esx'。")
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
                    print(('玩家 %s 已从 %s 中支付账单 %d（金额：%s%d），原因：%s。'):format(Player.getName() or Player.PlayerData.name, moneyType, billId, Config.CurrencySymbol, totalAmount, reason))
                else
                    print(('玩家 %s 没有足够的现金和银行余额来支付账单 %d（金额：%s%d），原因：%s。'):format(Player.getName() or Player.PlayerData.name, billId, Config.CurrencySymbol, totalAmount, reason))
                    goto continue
                end

                BillingSystem.MarkBillAsPaid(billId)
                print(('账单 %d 已标记为已支付。'):format(billId))

                ::continue::
            else
                if Config.AllowOfflinePayment then
                    print(('玩家 %s 不在线，但允许离线扣款。账单 %d（金额：%s%d），原因：%s 将稍后处理。'):format(receiverIdentifier, billId, Config.CurrencySymbol, totalAmount, reason))
                else
                    print(('玩家 %s 不在线。账单 %d（金额：%s%d），原因：%s 将稍后处理。'):format(receiverIdentifier, billId, Config.CurrencySymbol, totalAmount, reason))
                end
            end
        end
    else
        print("未找到未支付的账单。")
    end
end

Citizen.CreateThread(function()
    while true do
        AutomaticBilling()
        Citizen.Wait(Config.BillInterval)
    end
end)
