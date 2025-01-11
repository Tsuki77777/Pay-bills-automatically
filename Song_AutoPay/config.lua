Config = {}

-- 'qb' or 'esx'
Config.Framework = 'qb'

-- 自动扣款检查间隔（单位：毫秒） Automatic Deduction Check Interval (in milliseconds)
Config.BillInterval = 60 * 1000

Config.Priority = 'cash' -- 'cash' or'bank'   Automatic deduction priority

Config.LogLevel = 'info' -- 'debug', 'info', 'warn', 'error'

Config.AllowOfflinePayment = false -- 如果为 true，即使玩家不在线也会尝试扣款 If true, the charge will be attempted even if the player is not online

Config.BillingTable = 'okokbilling'

Config.CurrencySymbol = '$'