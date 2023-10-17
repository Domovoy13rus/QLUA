is_run = true

SEC    = "RMH3"  -- торгуемый инструмент 
CLASS  = "SPBFUT" -- класс торгуемого инструмента
ACCOUNT     = "XXXXXXX" -- здесь указывается число-буквенное значение аккаунта
CLIENT_CODE = XXXXXXXXX -- здесь должен быть цифровой код клиента
g_lots      = 2 -- количество торгуемых лотов
BUY_OFFERS  = "" -- количество заявок на покупку (по стакану), берется из функции OnQuote
SELL_OFFERS = "" -- количество заявок на продажу (по стакану), берется из функции OnQuote
B_D         = "" -- общий спрос, функция OnParam
S_D         = "" -- общее предложение, функция OnParam
BID_NOW     = "" -- лучшая цена покупки, получаем в функции OnParam
ASK_NOW     = "" -- лучшая цена продажи, получаем в функции OnParam
PRICE_SELL  = 0 -- цена сделки на продажу из функции OnParam
PRICE_BUY   = 0 -- цена сделки на покупку из функции OnParam
Total_Vol   = 0  -- Количество имеющихся лотов totalnet(NUMBER)
Sell_Vol_Act= 0  -- Количество лотов в заявках на продажу (NUMBER)
Buy_Vol_Act = 0  -- Количество лотов в заявках на продажу (NUMBER)
buy_uniq_trans_id = 2000  -- Начальный номер транзакций на покупку
sell_uniq_trans_id = 20000  -- Начальный номер транзакций на продажу
SL_TP_TransID = 0
LastStatus  = 0
Trans_Reply_ID = 0
FREE_MONEY         = 0 -- (план.чист.поз) денежные средства, доступные для торговли


-- блок функций работает, выдает сообщения о покупке/продаже/бездействии
function main()
    while is_run do
        if ((Total_Vol == 0) and (Sell_Vol_Act == 0) and (Buy_Vol_Act == 0)) then
        -- покупка, когда по стакану заявок на покупку больше, чем на продажу. 
        -- продажа - когда заявок на продажу больше, чем заявок на покупку.
            if (SELL_OFFERS > BUY_OFFERS) then -- if (S_D>B_D and SELL_OFFERS>BUY_OFFERS) then
                send_market_sell()
            elseif (BUY_OFFERS > SELL_OFFERS) then -- elseif (B_D>S_D and BUY_OFFERS>SELL_OFFERS) then
                send_market_buy()
            end
        elseif ((Trans_Reply_ID == buy_uniq_trans_id) and (LastStatus == 3)) then
            send_stop_profit_long()
        elseif ((Trans_Reply_ID == sell_uniq_trans_id) and (LastStatus == 3)) then
            send_stop_profit_short()
        end
        sleep(500)
    end
end

function OnStop()
    message("Stoped", 2)
    is_run = false
    return 5000
end

function OnFuturesClientHolding(fut_pos)
    Total_Vol = fut_pos.totalnet
    Sell_Vol_Act = fut_pos.opensells
    Buy_Vol_Act = fut_pos.openbuys
end

function OnFuturesLimitChange(fut_limit)
    FREE_MONEY = fut_limit.cbplplanned
end

function send_market_sell()
    sell_uniq_trans_id = sell_uniq_trans_id + 1
    send_market = {
        ACTION    = "NEW_ORDER",
        ACCOUNT   = ACCOUNT,
        OPERATION = "S",
        CLASSCODE = CLASS,
        SECCODE   = SEC,
        PRICE     = tostring(PRICE_SELL),
        QUANTITY  = tostring(g_lots),
        TRANS_ID  = tostring(sell_uniq_trans_id),
        TYPE      = "L"
    }
    res = sendTransaction(send_market)
    message("error: " .. res)
end

function send_market_buy()
    buy_uniq_trans_id = buy_uniq_trans_id + 1
    send_market = {
        ACTION    = "NEW_ORDER",
        ACCOUNT   = ACCOUNT,
        OPERATION = "B",
        CLASSCODE = CLASS,
        SECCODE   = SEC,
        PRICE     = tostring(PRICE_BUY),
        QUANTITY  = tostring(g_lots),
        TRANS_ID  = tostring(buy_uniq_trans_id),
        TYPE      = "L"
    }
    res = sendTransaction(send_market)
    message("error: " .. res)
end

function send_stop_profit_long()
    SL_TP_TransID = SL_TP_TransID + 1
    send_sl_tp_long = {
        ACTION          = "NEW_STOP_ORDER",
        ACCOUNT         = ACCOUNT,
        CLASSCODE       = CLASS,
        SECCODE         = SEC,
        OPERATION       = "S",
        STOP_ORDER_KIND = "TAKE_PROFIT_AND_STOP_LIMIT_ORDER",
        OFFSET          = "0",
        SPREAD          = "0",
        OFFSET_UNITS    = "PRICE_UNITS",
        SPREAD_UNITS    = "PRICE_UNITS",
        PRICE           = tostring(math.floor(PRICE_BUY - 2)),
        STOPPRICE       = tostring(math.floor(PRICE_BUY + 1)),
        STOPPRICE2      = tostring(math.floor(PRICE_BUY - 2)),
        QUANTITY        = tostring(g_lots),
        TRANS_ID        = tostring(SL_TP_TransID),
        TYPE            = "L"
    }
    res = sendTransaction(send_sl_tp_long)
    message("error: " .. res)
end

function send_stop_profit_short()
    SL_TP_TransID = SL_TP_TransID + 1
    send_sl_tp_long = {
        ACTION          = "NEW_STOP_ORDER",
        ACCOUNT         = ACCOUNT,
        CLASSCODE       = CLASS,
        SECCODE         = SEC,
        OPERATION       = "B",
        STOP_ORDER_KIND = "TAKE_PROFIT_AND_STOP_LIMIT_ORDER",
        OFFSET          = "0",
        SPREAD          = "0",
        OFFSET_UNITS    = "PRICE_UNITS",
        SPREAD_UNITS    = "PRICE_UNITS",
        PRICE           = tostring(math.floor(PRICE_SELL + 2)),
        STOPPRICE       = tostring(math.floor(PRICE_SELL - 1)),
        STOPPRICE2      = tostring(math.floor(PRICE_BUY + 2)),
        QUANTITY        = tostring(g_lots),
        TRANS_ID        = tostring(SL_TP_TransID),
        TYPE            = "L"
    }
    res = sendTransaction(send_sl_tp_long)
    message("error: " .. res)
end

function OnQuote(CLASS, SEC)
    if CLASS == "SPBFUT" and SEC == "RMH3" then
        local gql2=getQuoteLevel2(CLASS, SEC)
        local bu_of = nil -- переменная с заявкой на покупку
        local sel_of = nil -- переменная с заявкой на продажу
        local sum = 0
        for i = tonumber(gql2.bid_count), 1, -1 do
            bu_of = tonumber(gql2.bid[i].quantity)
            sum = sum + bu_of
            BUY_OFFERS = tostring(sum)
        end
        local sum1 = 0
        for i = 1, tonumber(gql2.offer_count) do
            sel_of = tonumber(gql2.offer[i].quantity)
            sum1 = sum1 + sel_of
            SELL_OFFERS = tostring(sum1)
        end
    end
end

function OnParam(CLASS, SEC)
    if CLASS == "SPBFUT" and SEC == "RMH3" then
        B_D = getParamEx(CLASS, SEC, "BIDDEPTHT").param_value -- общий спрос
        S_D = getParamEx(CLASS, SEC, "OFFERDEPTHT").param_value -- общее предложение
        BID_NOW = tonumber(getParamEx(CLASS, SEC, "BID").param_value) -- лучшая цена покупки
        ASK_NOW = tonumber(getParamEx(CLASS, SEC, "OFFER").param_value) -- лучшая цена продажи
        PRICE_SELL = tonumber(math.floor(ASK_NOW - 1))
        PRICE_BUY = tonumber(math.floor(BID_NOW + 1))
    end
end

function OnTransReply(trans_reply)
    Trans_Reply_ID = trans_reply.trans_id
    if (Trans_Reply_ID == buy_uniq_trans_id) or (Trans_Reply_ID == sell_uniq_trans_id) then
        LastStatus = trans_reply.status
    end
end

