local RunService = game:GetService("RunService")

local W, H = 290, 68
local PAD = 10
local MARGIN_X, MARGIN_Y = 18, 18
local OFFSCREEN = 360
local SLIDE_SPD = 12
local FADE_SPD = 2
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

local pool = {}
local loopConn = nil

local function vp() return workspace.CurrentCamera.ViewportSize end
local function targetX() return vp().X - W - MARGIN_X end

local function lerp(a, b, t) return a + (b - a) * t end

local function newSquare(pos, size, color, filled, thickness, zi)
    local s = Drawing.new("Square")
    s.Visible = true
    s.Position = pos
    s.Size = size
    s.Color = color
    s.Filled = filled
    s.Thickness = thickness or 1
    s.Transparency = 0.001
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
    t.Transparency = 0.001
    t.ZIndex = zi or 12
    return t
end

local function spawnDraw(x, y)
    local p = Vector2.new(x, y)
    local sz = Vector2.new(W, H)
    return {
        bg     = newSquare(p, sz, C.bg, true, 1, 10),
        border = newSquare(p, sz, C.border, false, 1, 11),
        accent = newSquare(p, Vector2.new(ACCENT_W, H), C.border, true, 1, 12),
        title  = newText(Vector2.new(x + 12, y + 14), "", 15, C.title, 13),
        msg    = newText(Vector2.new(x + 12, y + 36), "", 13, C.msg, 13)
    }
end

local function setAlpha(d, a)
    local t = math.clamp(a, 0.001, 0.999)
    d.bg.Transparency     = t
    d.border.Transparency = t
    d.accent.Transparency = t
    d.title.Transparency  = t
    d.msg.Transparency    = t
end

local function setPos(d, x, y)
    d.bg.Position     = Vector2.new(x, y)
    d.border.Position = Vector2.new(x, y)
    d.accent.Position = Vector2.new(x, y)
    d.title.Position  = Vector2.new(x + 12, y + 14)
    d.msg.Position    = Vector2.new(x + 12, y + 36)
end

local function destroy(d)
    d.bg:Remove()
    d.border:Remove()
    d.accent:Remove()
    d.title:Remove()
    d.msg:Remove()
end

local function startLoop()
    if loopConn then return end
    loopConn = RunService.RenderStepped:Connect(function(dt)
        local toRemove = {}

        for i = #pool, 1, -1 do
            local n = pool[i]
            n.cx = lerp(n.cx, targetX(), math.min(dt * SLIDE_SPD, 1))
            n.cy = lerp(n.cy, n.ty, math.min(dt * SLIDE_SPD, 1))

            if n.phase == "in" then
                n.alpha = math.min(n.alpha + dt * FADE_SPD, 1)
                if n.alpha >= 0.99 then n.phase = "hold" end
            elseif n.phase == "out" then
                n.alpha = math.max(n.alpha - dt * FADE_SPD, 0)
                if n.alpha <= 0.01 then
                    toRemove[#toRemove + 1] = i
                end
            end

            setAlpha(n.draw, n.alpha)
            setPos(n.draw, n.cx, n.cy)
        end

        for _, i in ipairs(toRemove) do
            destroy(pool[i].draw)
            table.remove(pool, i)
        end

        -- Stack from bottom
        for index, n in ipairs(pool) do
            n.ty = vp().Y - MARGIN_Y - ( (#pool - index + 1) * (H + PAD) )
        end

        if #pool == 0 then
            loopConn:Disconnect()
            loopConn = nil
        end
    end)
end

local function Notify(title, message, duration, notifType)
    notifType = notifType or "info"
    duration  = duration or 4
    title     = tostring(title or "Notification")
    message   = tostring(message or "")

    local accentColor = C.accent[notifType] or C.accent.info
    local ix = targetX() + OFFSCREEN
    local iy = vp().Y - MARGIN_Y - H

    local d = spawnDraw(ix, iy)
    d.accent.Color = accentColor
    d.title.Text   = title
    d.msg.Text     = message

    local n = {
        draw  = d,
        cx    = ix,
        cy    = iy,
        ty    = iy,
        alpha = 0,
        phase = "in"
    }

    table.insert(pool, n)
    startLoop()

    task.spawn(function()
        task.wait(duration)
        if n and n.phase ~= "out" then
            n.phase = "out"
            startLoop()
        end
    end)
end

return Notify
