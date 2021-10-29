--[[
    luaide  模板位置位于 Template/FunTemplate/NewFileTemplate.lua 其中 Template 为配置路径 与luaide.luaTemplatesDir
    luaide.luaTemplatesDir 配置 https://www.showdoc.cc/web/#/luaide?page_id=713062580213505
    author:{wkp}
    time:2021-10-28 14:42:23
]]
local filterHandler = class("filterHandler")

function filterHandler:ctor()
    self._config = L_Config:getConfig("filter")
    self._wordTree = {}
    self:createTree()
end

-- 构造屏蔽词树
function filterHandler:createTree()
    for i, v in pairs(self._config or {}) do
        if v.type == 0 then --串模式
            local word = v.word
            local node = self._wordTree
            local count = 0
            local length = self:utf8len(word)
            for char in string.gmatch(word, "[%z\1-\127\194-\244][\128-\191]*") do
                count = count + 1
                if node[char] then
                    node = node[char]
                else
                    local newNode = {}
                    newNode["end"] = 0
                    node[char] = newNode
                    node = newNode;
                end
                --尾部标识end
                if length == count then
                    node["end"] = 1
                    node["tips"] = v.tips
                end
            end
        else --正则模式
        end
    end
    --__(Util.addTextColor("屏蔽词树","ff0000"),self._wordTree)
end

function filterHandler:sequenceFilter(chars,beginIndex)
    local map = self._wordTree
    local len = 0
    local flag = false
    local tips
    for i = beginIndex, #chars do
        local temp = map[chars[i]]
        --__(chars,i)
        if temp ~= nil then
            if temp["end"] == 1 then
                flag = true
                --break
                tips = temp.tips
            else
                map = temp
            end
            len = len + 1
        else
            break
        end
    end
    if not flag then
        len = 0
    end
    return len,tips
end

-- 严格匹配,存在序列字符匹配上屏蔽串就不予通过
function filterHandler:strictFilter(chars)
    local map = self._wordTree
    local len = 0
    local flag = false
    local indexList = {}
    local tips
    for i = 1, #chars do
        local temp = map[chars[i]]
        if temp ~= nil then
            if temp["end"] == 1 then
                flag = true
                tips = temp.tips
                --break
            else
                map = temp
            end
            len = len + 1
            table.insert(indexList,i)
        end
    end
    if #indexList > 0 and flag then
        return indexList,tips
    end
end

function filterHandler:checkFilter(txt,replace,replaceChar,notStrict)
    replaceChar = replace and replaceChar or '*'
    local chars = {}
    for char in string.gmatch(txt, "[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(chars,char)
    end
    local resTable = chars
    local i = 1
    local pass = true
    if notStrict then --非严格模式
        local tips
        while(i < #chars) do
            local len,tp = self:sequenceFilter(chars,i)
            --__(len)
            if len > 0 then
                if replace then
                    for j = 0, len - 1 do
                        resTable[i + j] = replaceChar
                    end
                end
                pass = false
                i = i + len
                tips = tp
            else
                i = i + 1
            end
        end
        return pass,table.concat(resTable),tips
    else
        local indexList,tips = self:strictFilter(chars)
        local res = txt
        if indexList then
            pass = false
            if replace then
                for _, index in pairs(indexList) do
                    resTable[index] = replaceChar
                end
                res = table.concat(resTable)
            end
        else
            pass = true
        end
        return pass,res,tips
    end
end

-- utf8长度
function filterHandler:utf8len(str)
    local len  = string.len(str)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(str, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

return filterHandler