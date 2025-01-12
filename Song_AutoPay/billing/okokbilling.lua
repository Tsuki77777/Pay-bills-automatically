local OkokBilling = {}

function OkokBilling.GetUnpaidBills()
    local query = "SELECT * FROM okokbilling WHERE status = 'unpaid'"
    local result = MySQL.Sync.fetchAll(query, {})
    return result
end

function OkokBilling.MarkBillAsPaid(billId)
    local query = "UPDATE okokbilling SET status = 'paid', paid_date = NOW() WHERE id = ?"
    MySQL.Sync.execute(query, {billId})
end

return OkokBilling