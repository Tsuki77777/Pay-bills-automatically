fx_version 'cerulean'
game 'gta5'

author 'LoveSong_恋曲'
description '基于okok账单自动扣款'
version '1.0.0'

shared_scripts {
    'config.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'okokBilling',
    'oxmysql'
}