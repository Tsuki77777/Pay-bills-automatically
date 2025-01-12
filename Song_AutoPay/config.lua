Config = {}

-- （'qb' or 'esx'）
Config.Framework = 'qb'

-- （'okokbilling' or 'esx'）
Config.BillingSystem = 'okokbilling'

Config.BillInterval = 60 * 1000

Config.Priority = 'cash' -- 'cash'（Priority cash deduction），'bank'（Priority bank debit）

Config.LogLevel = 'info' -- 'debug', 'info', 'warn', 'error'

Config.AllowOfflinePayment = false -- If true, the charge will be attempted even if the player is not online

-- Bill table name (dynamically set based on the billing system)
Config.BillingTable = Config.BillingSystem == 'okokbilling' and 'okokbilling' or 'billing'

-- Currency symbols
Config.CurrencySymbol = '$' -- Used to display the amount in the log