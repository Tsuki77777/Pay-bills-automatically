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
    print("错误：未检测到支持的框架类型。请在 config.lua 中设置 Config.Framework 为 'qb' 或 'esx'。")---"Error: Supported frame type not detected. Please set the Config.Framework to 'qb' or 'esx' in config.lua. "
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
                        print(('玩家 %s 已从 %s 中支付账单 %d（金额：%s%d），原因：%s。'):format(Player.getName() or Player.PlayerData.name, moneyType, billId, Config.CurrencySymbol, totalAmount, reason))--'Player %s has paid bill %d from %s (amount: %s%d) and reason: %s. '
                    else
                        print(('玩家 %s 没有足够的现金和银行余额来支付账单 %d（金额：%s%d），原因：%s。'):format(Player.getName() or Player.PlayerData.name, billId, Config.CurrencySymbol, totalAmount, reason))--'Player %s does not have enough cash and bank balance to pay the bill %d (amount: %s%d), reason: %s. '
                        goto continue
                    end

                    exports.oxmysql:update("UPDATE " .. Config.BillingTable .. " SET status = 'paid', paid_date = NOW() WHERE id = ?", {billId}, function(rowsChanged)
                        if rowsChanged > 0 then
                            print(('账单 %d 已标记为已支付。'):format(billId))--'Bill %d has been marked as paid. '
                        end
                    end)

                    ::continue::
                else
                    if Config.AllowOfflinePayment then
                        print(('玩家 %s 不在线，但允许离线扣款。账单 %d（金额：%s%d），原因：%s 将稍后处理。'):format(receiverIdentifier, billId, Config.CurrencySymbol, totalAmount, reason))--'Player %s is not online, but offline charges are allowed. Bill %d (amount: %s%d), reason: %s will be processed later. '
                    else
                        print(('玩家 %s 不在线。账单 %d（金额：%s%d），原因：%s 将稍后处理。'):format(receiverIdentifier, billId, Config.CurrencySymbol, totalAmount, reason))--'Player %s is not online. Bill %d (amount: %s%d), reason: %s will be processed later. '
                    end
                end
            end
        else
            print("未找到未支付的账单。")--Unpaid bills were not found.
        end
    end)
end

Citizen.CreateThread(function()
    while true do
        AutomaticBilling()
        Citizen.Wait(Config.BillInterval)
    end
end)