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
    print("Error: Supported frame type not detected. Please set the Config.Framework to 'qb' or 'esx' in config.lua. ")---"Error: Supported frame type not detected. Please set the Config.Framework to 'qb' or 'esx' in config.lua. "
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
    local query = ("SELECT * FROM %s WHERE status = 'unpaid'"):format(Config.BillingTable)
    exports.oxmysql:query(query, {}, function(result)
        if result and #result > 0 then
            for _, bill in ipairs(result) do
                local receiverIdentifier = bill.receiver_identifier
                local invoiceValue = bill.invoice_value
                local feesAmount = bill.fees_amount
                local totalAmount = invoiceValue + feesAmount
                local billId = bill.id
                local reason = bill.item

                local Player = GetPlayer(receiverIdentifier)
                if Player then
                    local success, moneyType = RemoveMoney(Player, totalAmount, reason)
                    if success then
                        print(('Player %s has paid bill %d from %s (amount: %s%d) and reason: %s.'):format(Player.getName() or Player.PlayerData.name, moneyType, billId, Config.CurrencySymbol, totalAmount, reason))--' '
                    else
                        print(('Player %s does not have enough cash and bank balance to pay the bill %d (amount: %s%d), reason: %s. '):format(Player.getName() or Player.PlayerData.name, billId, Config.CurrencySymbol, totalAmount, reason))--''
                        goto continue
                    end

                    exports.oxmysql:update("UPDATE " .. Config.BillingTable .. " SET status = 'paid', paid_date = NOW() WHERE id = ?", {billId}, function(rowsChanged)
                        if rowsChanged > 0 then
                            print(('Bill %d has been marked as paid. '):format(billId))--
                        end
                    end)

                    ::continue::
                else
                    if Config.AllowOfflinePayment then
                        print(('Player %s is not online, but offline charges are allowed. Bill %d (amount: %s%d), reason: %s will be processed later.'):format(receiverIdentifier, billId, Config.CurrencySymbol, totalAmount, reason))--' '
                    else
                        print(('Player %s is not online. Bill %d (amount: %s%d), reason: %s will be processed later.'):format(receiverIdentifier, billId, Config.CurrencySymbol, totalAmount, reason))--' '
                    end
                end
            end
        else
            print("Unpaid bills were not found.")
        end
    end)
end

Citizen.CreateThread(function()
    while true do
        AutomaticBilling()
        Citizen.Wait(Config.BillInterval)
    end
end)