local ESXBilling = {}

function ESXBilling.GetUnpaidBills()
    local query = "SELECT * FROM billing WHERE paid = 0" -- 假设有一个 paid 字段来标记是否已支付
    local result = MySQL.Sync.fetchAll(query, {})
    return result
end

function ESXBilling.MarkBillAsPaid(billId)
    local query = "UPDATE billing SET paid = 1, paid_date = NOW() WHERE id = ?"
    MySQL.Sync.execute(query, {billId})
end

return ESXBilling