--[[--
Icons Changer Plugin for KOReader

This plugin allows changing the icon pack used in the UI by downloading icons from Iconify API
and mapping them according to icon pack configurations.

@module koplugin.IconsChanger
--]]--

local DataStorage = require("datastorage")
local FFIUtil = require("ffi/util")
local InfoMessage = require("ui/widget/infomessage")
local rapidjson = require("rapidjson")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
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

function IconsChanger:getPredefinedColors()
    return {
        { name = _("Black"), hex = "000000" },
        { name = _("White"), hex = "ffffff" },
        { name = _("Dark Gray"), hex = "404040" },
        { name = _("Light Gray"), hex = "808080" },
        { name = _("Blue"), hex = "0066cc" },
        { name = _("Green"), hex = "00cc66" },
        { name = _("Red"), hex = "cc0000" },
        { name = _("Orange"), hex = "ff6600" },
        { name = _("Purple"), hex = "6600cc" },
        { name = _("Brown"), hex = "996633" },
    }
end

function IconsChanger:init()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/iconschanger.lua")
    self.icon_packs_dir = self.path .. "/iconpacks"
    
    -- Use KOReader's user icons directory instead of overwriting system icons
    self.user_icons_dir = DataStorage:getDataDir() .. "/icons"
    self.system_icons_dir = "resources/icons/mdlight"  -- Keep reference for migration
    self.backup_dir = DataStorage:getSettingsDir() .. "/iconschanger_backup"
    
    -- Ensure directories exist
    if not lfs.attributes(self.icon_packs_dir, "mode") then
        lfs.mkdir(self.icon_packs_dir)
    end
    if not lfs.attributes(self.user_icons_dir, "mode") then
        lfs.mkdir(self.user_icons_dir)
    end
    
    -- Handle migration from old version that overwrote system icons
    self:handleMigrationFromSystemIcons()
    
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
    self.settings:flush()
end

function IconsChanger:getIconColor()
    return self.settings:readSetting("icon_color", "000000")
end

function IconsChanger:setIconColor(color_hex)
    -- Remove # if present and validate hex format
    color_hex = color_hex:gsub("#", "")
    if color_hex:match("^%x%x%x%x%x%x$") then
        self.settings:saveSetting("icon_color", color_hex)
        self.settings:flush()
        return true
    end
    return false
end

function IconsChanger:getIconPackMenuItems()
    local menu_items = {}
    local active_pack = self:getActiveIconPack()
    
    -- Add color configuration option at the top with separator
    table.insert(menu_items, {
        text = _("Choose Icon Color"),
        separator = true,
        sub_item_table_func = function()
            return self:getColorMenuItems()
        end,
    })
    
    -- Add "Original Icons" as first option (no separator, treated like other packs)
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

function IconsChanger:getColorMenuItems()
    local menu_items = {}
    local current_color = self:getIconColor()
    
    -- Show current color
    table.insert(menu_items, {
        text = T(_("Current Color: #%1"), current_color),
        enabled = false,
    })
    
    -- Add custom color option right after current color with separator
    table.insert(menu_items, {
        text = _("Custom Color (Hex)"),
        separator = true,
        callback = function()
            self:showCustomColorDialog()
        end,
    })
    
    -- Add predefined colors (all treated the same, no separator)
    for _, color_info in ipairs(self:getPredefinedColors()) do
        local color_text = color_info.name
        if current_color:lower() == color_info.hex:lower() then
            color_text = color_text .. " ✓"
        end
        table.insert(menu_items, {
            text = color_text,
            callback = function()
                self:setIconColor(color_info.hex)
                UIManager:show(InfoMessage:new{
                    text = T("Color set to %1 (#%2)", color_info.name, color_info.hex),
                    timeout = 2,
                })
            end,
        })
    end
    
    return menu_items
end

function IconsChanger:showCustomColorDialog()
    local input_dialog
    input_dialog = InputDialog:new{
        title = _("Enter Custom Color"),
        input_hint = _("Enter hex color (e.g., ff0000 or #ff0000)"),
        input = "#" .. self:getIconColor(),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = _("Apply"),
                    callback = function()
                        local color_input = input_dialog:getInputText()
                        if self:setIconColor(color_input) then
                            UIManager:close(input_dialog)
                            UIManager:show(InfoMessage:new{
                                text = T("Custom color set to #%1", color_input:gsub("#", "")),
                                timeout = 2,
                            })
                        else
                            UIManager:show(InfoMessage:new{
                                text = "Invalid hex color format. Use 6 hex digits (e.g., ff0000)",
                                timeout = 3,
                            })
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function IconsChanger:restoreOriginalIcons()
    -- For the new user icons approach, we just remove user icons
    if lfs.attributes(self.user_icons_dir, "mode") == "directory" then
        -- Remove all user icons
        for file in lfs.dir(self.user_icons_dir) do
            if file:match("%.svg$") then
                local user_icon_file = self.user_icons_dir .. "/" .. file
                if lfs.attributes(user_icon_file, "mode") == "file" then
                    os.remove(user_icon_file)
                end
            end
        end
        
        -- Mark original icons as active
        self:setActiveIconPack("original")
        
        UIManager:show(InfoMessage:new{
            text = _("Original icons restored! Please restart KOReader."),
        })
    else
        UIManager:show(InfoMessage:new{
            text = _("No custom icons to remove"),
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
    
    
    -- Download and apply icons from Iconify API
    NetworkMgr:runWhenOnline(function()
        self:downloadAndApplyIcons(mapping, pack_path)
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
    
    -- Get the current color setting
    local icon_color = self:getIconColor()
    
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
            local url = "https://api.iconify.design/" .. prefix .. "/" .. icon_name .. ".svg?color=%23" .. icon_color
            
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
                local icon_file = self.user_icons_dir .. "/" .. icon_info.current .. ".svg"
                local file = io.open(icon_file, "w")
                if file then
                    file:write(body_or_error)
                    file:close()
                    success_count = success_count + 1
                    logger.info("IconsChanger: Successfully downloaded", icon_info.current, "to user icons directory")
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
            status_text = T(_("Successfully downloaded %1 icons with color #%2! Please restart KOReader."), success_count, icon_color)
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
    -- For backwards compatibility, we still keep this function
    -- but it's only used during migration now
    local backup_done_file = self.backup_dir .. "/.backup_done"
    if lfs.attributes(backup_done_file, "mode") then
        return -- backup already exists
    end
    
    -- Only backup if system icons directory exists and we haven't backed up yet
    if lfs.attributes(self.system_icons_dir, "mode") == "directory" then
        for file in lfs.dir(self.system_icons_dir) do
            if file:match("%.svg$") then
                FFIUtil.copyFile(self.system_icons_dir .. "/" .. file, self.backup_dir .. "/" .. file)
            end
        end
        local marker = io.open(backup_done_file, "w")
        if marker then
            marker:write("backup completed")
            marker:close()
        end
    end
end

function IconsChanger:handleMigrationFromSystemIcons()
    -- Check if we have a backup (indicating the old version was used)
    local backup_done_file = self.backup_dir .. "/.backup_done"
    local migration_done_file = self.backup_dir .. "/.migration_done"
    
    -- If we have a backup but haven't migrated yet
    if lfs.attributes(backup_done_file, "mode") and not lfs.attributes(migration_done_file, "mode") then
        logger.info("IconsChanger: Migrating from old version that modified system icons")
        
        -- Step 1: Restore original system icons from backup
        if lfs.attributes(self.backup_dir, "mode") == "directory" then
            for file in lfs.dir(self.backup_dir) do
                if file:match("%.svg$") then
                    local backup_file = self.backup_dir .. "/" .. file
                    local system_file = self.system_icons_dir .. "/" .. file
                    if lfs.attributes(backup_file, "mode") == "file" then
                        FFIUtil.copyFile(backup_file, system_file)
                        logger.dbg("IconsChanger: Restored system icon:", file)
                    end
                end
            end
        end
        
        -- Step 2: Check if user had an active icon pack and preserve it in user directory
        local active_pack = self:getActiveIconPack()
        if active_pack ~= "original" then
            logger.info("IconsChanger: Preserving active icon pack in user directory:", active_pack)
            -- The current system icons are the user's chosen pack, so copy them to user directory
            if lfs.attributes(self.system_icons_dir, "mode") == "directory" then
                for file in lfs.dir(self.system_icons_dir) do
                    if file:match("%.svg$") and file ~= "." and file ~= ".." then
                        local system_file = self.system_icons_dir .. "/" .. file
                        local user_file = self.user_icons_dir .. "/" .. file
                        -- Only copy if the file was likely modified by our plugin
                        FFIUtil.copyFile(system_file, user_file)
                    end
                end
            end
            
            -- Now restore the original system icons
            if lfs.attributes(self.backup_dir, "mode") == "directory" then
                for file in lfs.dir(self.backup_dir) do
                    if file:match("%.svg$") then
                        local backup_file = self.backup_dir .. "/" .. file
                        local system_file = self.system_icons_dir .. "/" .. file
                        if lfs.attributes(backup_file, "mode") == "file" then
                            FFIUtil.copyFile(backup_file, system_file)
                        end
                    end
                end
            end
        end
        
        -- Mark migration as completed
        local marker = io.open(migration_done_file, "w")
        if marker then
            marker:write("migration completed from system icons to user icons")
            marker:close()
        end
        
        logger.info("IconsChanger: Migration completed successfully")
    end
end

function IconsChanger:getAvailableIconPacksFromConfig()
    local config_file = self.path .. "/config.json"
    local file = io.open(config_file, "r")
    if not file then
        logger.warn("IconsChanger: config.json not found")
        return {}
    end
    
    local config_content = file:read("*all")
    file:close()
    
    local success, config = pcall(rapidjson.decode, config_content)
    if not success or type(config) ~= "table" then
        logger.warn("IconsChanger: Invalid config.json format")
        return {}
    end
    
    return config
end

return IconsChanger
