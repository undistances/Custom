local RunService = game:GetService("RunService")

local W, H = 290, 68
local MARGIN_X, MARGIN_Y = 18, 18
local ACCENT_W = 3

local C = {
    bg = Color3.fromRGB(22, 22, 33),
    border = Color3.fromRGB(48, 48, 68),
    title = Color3.fromRGB(235, 235, 250),
    msg = Color3.fromRGB(155, 155, 178),
    accent = {
        info    = Color3.fromRGB(80, 148, 255),
        success = Color3.fromRGB(72, 199, 116),
        warning = Color3.fromRGB(255, 178, 50),
        error   = Color3.fromRGB(255, 75, 75)
    }
}

local currentNotif = nil

local function vp() return workspace.CurrentCamera.ViewportSize end
local function targetX() return vp().X - W - MARGIN_X end
local function targetY() return vp().Y - MARGIN_Y - H end

local function newSquare(pos, size, color, filled, thickness, zi)
    local s = Drawing.new("Square")
    s.Visible = true
    s.Position = pos
    s.Size = size
    s.Color = color
    s.Filled = filled
    s.Thickness = thickness or 1
    s.Transparency = 1
    s.ZIndex = zi or 10
    return s
end

local function newText(pos, text, size, color, zi)
    local t = Drawing.new("Text")
    t.Visible = true
    t.Position = pos
    t.Text = text
    t.Size = size
    t.Color = color
    t.Font = Drawing.Fonts.UI
    t.Outline = false
    t.Transparency = 1
    t.ZIndex = zi or 12
    return t
end

local function destroy(d)
    if d then
        d.bg:Remove()
        d.border:Remove()
        d.accent:Remove()
        d.title:Remove()
        d.msg:Remove()
    end
end

local function Notify(title, message, duration, notifType)
    notifType = notifType or "info"
    duration  = duration or 4
    title     = tostring(title or "Notification")
    message   = tostring(message or "")

    -- remove the old notification immediately
    if currentNotif then
        destroy(currentNotif)
        currentNotif = nil
    end

    local x = targetX()
    local y = targetY()

    local d = {
        bg     = newSquare(Vector2.new(x, y), Vector2.new(W, H), C.bg, true),
        border = newSquare(Vector2.new(x, y), Vector2.new(W, H), C.border, false),
        accent = newSquare(Vector2.new(x, y), Vector2.new(ACCENT_W, H), C.accent[notifType] or C.accent.info, true),
        title  = newText(Vector2.new(x + 12, y + 14), title, 15, C.title),
        msg    = newText(Vector2.new(x + 12, y + 36), message, 13, C.msg)
    }

    currentNotif = d

    task.spawn(function()
        task.wait(duration)
        destroy(d)
        if currentNotif == d then
            currentNotif = nil
        end
    end)
end

return Notify
