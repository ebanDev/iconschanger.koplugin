--[[--
Icons Changer Plugin for KOReader

This plugin allows changing the icon pack used in the UI by downloading icons from Iconify API
and mapping them according to icon pack configurations.

@module koplugin.IconsChanger
--]]--

local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local FFIUtil = require("ffi/util")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local rapidjson = require("rapidjson")
local LuaSettings = require("luasettings")
local Menu = require("ui/widget/menu")
local NetworkMgr = require("ui/network/manager")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")
local socketutil = require("socketutil")
local http = require("socket.http")
local ltn12 = require("ltn12")
local _ = require("gettext")
local T = require("ffi/util").template

local IconsChanger = WidgetContainer:extend{
    name = "iconschanger",
    is_doc_only = false,
}

-- Register this plugin in the more_tools menu
require("ui/plugin/insert_menu").add("icons_changer")

function IconsChanger:init()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/iconschanger.lua")
    self.icon_packs_dir = self.path .. "/iconpacks"
    self.icons_dir = "resources/icons/mdlight"
    self.backup_dir = DataStorage:getSettingsDir() .. "/iconschanger_backup"
    
    -- Ensure directories exist
    if not lfs.attributes(self.backup_dir, "mode") then
        lfs.mkdir(self.backup_dir)
    end
    if not lfs.attributes(self.icon_packs_dir, "mode") then
        lfs.mkdir(self.icon_packs_dir)
    end
    
    self.ui.menu:registerToMainMenu(self)
end

function IconsChanger:addToMainMenu(menu_items)
    menu_items.icons_changer = {
        text = _("Icon Pack Changer"),
        sub_item_table_func = function()
            return self:getIconPackMenuItems()
        end,
    }
end

function IconsChanger:getActiveIconPack()
    return self.settings:readSetting("active_icon_pack", "original")
end

function IconsChanger:setActiveIconPack(pack_identifier)
    self.settings:saveSetting("active_icon_pack", pack_identifier)
end

function IconsChanger:getIconPackMenuItems()
    local menu_items = {}
    local active_pack = self:getActiveIconPack()
    
    -- Add "Original Icons" as first option
    local original_text = _("Original Icons")
    if active_pack == "original" then
        original_text = original_text .. " ✓"
    end
    table.insert(menu_items, {
        text = original_text,
        callback = function()
            self:restoreOriginalIcons()
        end,
    })
    
    -- Get all packs from config.json
    local available_packs = self:getAvailableIconPacksFromConfig()
    
    if #available_packs == 0 then
        table.insert(menu_items, {
            text = _("No icon packs found"),
            enabled = false,
        })
        table.insert(menu_items, {
            text = _("Check config.json file"),
            enabled = false,
        })
    else
        for _, pack in ipairs(available_packs) do
            local pack_text = pack.display_name
            if active_pack == pack.path then
                pack_text = pack_text .. " ✓"
            end
            table.insert(menu_items, {
                text = pack_text,
                callback = function()
                    self:applyIconPack(pack.path)
                end,
            })
        end
    end
    
    return menu_items
end

function IconsChanger:getAvailableIconPacksFromConfig()
    local packs = {}
    local config_file = self.path .. "/config.json"
    
    local file = io.open(config_file, "r")
    if not file then
        logger.warn("IconsChanger: config.json not found")
        return packs
    end
    
    local config_data = rapidjson.decode(file:read("*all"))
    file:close()
    
    if not config_data then
        logger.warn("IconsChanger: Invalid config.json file")
        return packs
    end
    
    -- Validate each pack configuration
    for _, pack_config in ipairs(config_data) do
        if pack_config.display_name and pack_config.path then
            local pack_file_path = self.path .. "/" .. pack_config.path
            if lfs.attributes(pack_file_path, "mode") == "file" then
                table.insert(packs, {
                    display_name = pack_config.display_name,
                    path = pack_config.path,
                })
            else
                logger.warn("IconsChanger: Pack file not found:", pack_file_path)
            end
        else
            logger.warn("IconsChanger: Invalid pack configuration:", pack_config)
        end
    end
    
    return packs
end

function IconsChanger:restoreOriginalIcons()
    local backup_done_file = self.backup_dir .. "/.backup_done"
    if not lfs.attributes(backup_done_file, "mode") then
        UIManager:show(InfoMessage:new{
            text = _("No backup found"),
        })
        return
    end
    
    if lfs.attributes(self.backup_dir, "mode") == "directory" then
        for file in lfs.dir(self.backup_dir) do
            if file:match("%.svg$") then
                FFIUtil.copyFile(self.backup_dir .. "/" .. file, self.icons_dir .. "/" .. file)
            end
        end
        
        -- Mark original icons as active
        self:setActiveIconPack("original")
        
        UIManager:show(InfoMessage:new{
            text = _("Original icons restored! Please restart KOReader."),
        })
    end
end

function IconsChanger:applyIconPack(pack_path)
    local file = io.open(self.path .. "/" .. pack_path, "r")
    if not file then
        UIManager:show(InfoMessage:new{
            text = _("Failed to read icon pack file"),
        })
        return
    end
    
    local mapping = rapidjson.decode(file:read("*all"))
    file:close()
    
    if not mapping then
        UIManager:show(InfoMessage:new{
            text = _("Invalid icon pack file"),
        })
        return
    end
    
    UIManager:show(InfoMessage:new{
        text = _("Downloading and applying icon pack..."),
        timeout = 2,
    })
    
    self:backupCurrentIcons()
    
    -- Store the pack path for tracking active pack
    local current_pack_path = pack_path
    
    -- Download and apply icons from Iconify API
    NetworkMgr:runWhenOnline(function()
        self:downloadAndApplyIcons(mapping, current_pack_path)
    end)
end

function IconsChanger:downloadAndApplyIcons(mapping, pack_path)
    local total_icons = 0
    local success_count = 0
    local failed_count = 0
    
    -- Count total icons
    for _, _ in pairs(mapping) do
        total_icons = total_icons + 1
    end
    
    if total_icons == 0 then
        UIManager:show(InfoMessage:new{
            text = _("No icons to process"),
        })
        return
    end
    
    -- Convert mapping to array for sequential processing
    local icons_to_process = {}
    for current_icon, iconify_id in pairs(mapping) do
        table.insert(icons_to_process, {
            current = current_icon,
            iconify_id = iconify_id
        })
    end
    
    local Trapper = require("ui/trapper")
    Trapper:wrap(function()
        Trapper:setPausedText("Download paused.\nDo you want to continue or abort downloading icons?")
        
        for index, icon_info in ipairs(icons_to_process) do
            -- Extract prefix from the iconify_id (everything before the first hyphen)
            local prefix = icon_info.iconify_id:match("^([^-]+)")
            if not prefix then
                logger.warn("IconsChanger: Could not extract prefix from", icon_info.iconify_id)
                failed_count = failed_count + 1
                goto continue
            end
            
            local icon_name = icon_info.iconify_id:sub(#prefix + 2) -- Remove prefix and hyphen
            local url = "https://api.iconify.design/" .. prefix .. "/" .. icon_name .. ".svg?color=%23000000"
            
            -- Update progress display
            local progress_text = T(_("Downloading icons (%1/%2): %3"), index, total_icons, icon_info.current)
            local go_on = Trapper:info(progress_text)
            if not go_on then
                Trapper:clear()
                UIManager:show(InfoMessage:new{
                    text = _("Download cancelled"),
                    timeout = 2,
                })
                return
            end
            
            logger.dbg("IconsChanger: Downloading", icon_info.current, "from", url)
            
            -- Download synchronously
            local success, body_or_error = self:httpRequestSync(url)
            
            if success then
                local icon_file = self.icons_dir .. "/" .. icon_info.current .. ".svg"
                local file = io.open(icon_file, "w")
                if file then
                    file:write(body_or_error)
                    file:close()
                    success_count = success_count + 1
                    logger.info("IconsChanger: Successfully downloaded", icon_info.current)
                else
                    failed_count = failed_count + 1
                    logger.warn("IconsChanger: Failed to write file for", icon_info.current)
                end
            else
                failed_count = failed_count + 1
                logger.warn("IconsChanger: Failed to download", icon_info.current, "->", icon_info.iconify_id, "Error:", body_or_error)
            end
            
            ::continue::
        end
        
        -- If download was successful, mark this pack as active
        if success_count > 0 then
            self:setActiveIconPack(pack_path)
        end
        
        -- Show final status
        local status_text
        if failed_count == 0 then
            status_text = T(_("Successfully downloaded %1 icons! Please restart KOReader."), success_count)
        else
            status_text = T(_("Downloaded %1 icons, %2 failed. Please restart KOReader."), success_count, failed_count)
        end
        Trapper:clear()
        UIManager:show(InfoMessage:new{
            text = status_text,
            timeout = 4,
        })
    end)
end

function IconsChanger:httpRequestSync(url)
    local sink = {}
    
    logger.dbg("IconsChanger: Making HTTP request to", url)
    
    -- Set timeouts like CloudStorage does
    socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
    
    local request = {
        url = url,
        method = "GET",
        sink = ltn12.sink.table(sink),
        headers = {
            ["User-Agent"] = "KOReader/" .. require("version"):getCurrentRevision(),
        }
    }
    
    local code, headers, status = http.request(request)
    socketutil:reset_timeout()
    
    logger.dbg("IconsChanger: HTTP response - code:", code, "headers type:", type(headers))
    
    -- Handle LuaSocket's confusing return values
    if code == 1 then
        -- Success case for LuaSocket - code=1 means success, headers contains actual headers
        local body = table.concat(sink)
        if body and #body > 0 then
            logger.dbg("IconsChanger: Successfully received", #body, "bytes")
            return true, body
        else
            logger.warn("IconsChanger: Empty response body for", url)
            return false, "Empty response body"
        end
    else
        -- Error case
        logger.warn("IconsChanger: HTTP request failed - code:", code, "headers:", type(headers) == "table" and "table" or headers)
        if type(headers) == "string" then
            return false, headers
        else
            return false, "Network error"
        end
    end
end

function IconsChanger:backupCurrentIcons()
    local backup_done_file = self.backup_dir .. "/.backup_done"
    if lfs.attributes(backup_done_file, "mode") then
        return -- backup already exists
    end
    
    if lfs.attributes(self.icons_dir, "mode") == "directory" then
        for file in lfs.dir(self.icons_dir) do
            if file:match("%.svg$") then
                FFIUtil.copyFile(self.icons_dir .. "/" .. file, self.backup_dir .. "/" .. file)
            end
        end
        local marker = io.open(backup_done_file, "w")
        if marker then
            marker:write("backup completed")
            marker:close()
        end
    end
end

return IconsChanger
