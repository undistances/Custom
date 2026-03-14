--[[
  Linoria Styled SendNotification
  @12345rtxc @xpltacy
]]
local RunService = game:GetService("RunService")

local CONFIG = {
    Dimensions = {
        Width      = 290,
        Height     = 68,
        AccentWidth = 3,
    },
    
    Positioning = {
        Padding     = 10,
        MarginX     = 18,
        MarginY     = 18,
        Offscreen   = 360,
    },
    
    Animation = {
        SlideSpeed  = 12,
        FadeSpeed   = 2,
    },
    
    Typography = {
        TitleSize   = 15,
        MessageSize = 13,
        TitleOffset = 14,
        MessageOffset = 36,
        SidePadding = 12,
    },
}

local PALETTE = {
    Background  = Color3.fromRGB(22, 22, 33),
    Border      = Color3.fromRGB(48, 48, 68),
    Title       = Color3.fromRGB(235, 235, 250),
    Message     = Color3.fromRGB(155, 155, 178),
    
    Accent = {
        Info     = Color3.fromRGB(80, 148, 255),
        Success  = Color3.fromRGB(72, 199, 116),
        Warning  = Color3.fromRGB(255, 178, 50),
        Error    = Color3.fromRGB(255, 75, 75),
    },
}

local NotificationQueue = {}
local RenderConnection = nil

local function GetScreenSize()
    return workspace.CurrentCamera.ViewportSize
end

local function CalculateTargetX()
    return GetScreenSize().X - CONFIG.Dimensions.Width - CONFIG.Positioning.MarginX
end

local function CalculateTargetY(Slot)
    return CONFIG.Positioning.MarginY + (Slot - 1) * (CONFIG.Dimensions.Height + CONFIG.Positioning.Padding)
end

local function Lerp(Start, Goal, Alpha)
    return Start + (Goal - Start) * Alpha
end

local DrawingFactory = {}

function DrawingFactory:CreateSquare(Position, Size, Color, Filled, Thickness, ZIndex)
    local Square = Drawing.new("Square")
    Square.Visible = true
    Square.Position = Position
    Square.Size = Size
    Square.Color = Color
    Square.Filled = Filled
    Square.Thickness = Thickness or 1
    Square.Transparency = 0
    Square.ZIndex = ZIndex or 10
    return Square
end

function DrawingFactory:CreateText(Position, Text, Size, Color, ZIndex)
    local TextObject = Drawing.new("Text")
    TextObject.Visible = true
    TextObject.Position = Position
    TextObject.Text = Text
    TextObject.Size = Size
    TextObject.Color = Color
    TextObject.Font = Drawing.Fonts.UI
    TextObject.Outline = false
    TextObject.Transparency = 0
    TextObject.ZIndex = ZIndex or 12
    return TextObject
end

local Notification = {}
Notification.__index = Notification

function Notification.new(X, Y)
    local self = setmetatable({}, Notification)
    
    local Position = Vector2.new(X, Y)
    local Size = Vector2.new(CONFIG.Dimensions.Width, CONFIG.Dimensions.Height)
    local AccentSize = Vector2.new(CONFIG.Dimensions.AccentWidth, CONFIG.Dimensions.Height)
    
    self.Drawings = {
        Background = DrawingFactory:CreateSquare(Position, Size, PALETTE.Background, true, 1, 10),
        Border     = DrawingFactory:CreateSquare(Position, Size, PALETTE.Border, false, 1, 11),
        Accent     = DrawingFactory:CreateSquare(Position, AccentSize, PALETTE.Border, true, 1, 12),
        Title      = DrawingFactory:CreateText(Vector2.new(), "", CONFIG.Typography.TitleSize, PALETTE.Title, 13),
        Message    = DrawingFactory:CreateText(Vector2.new(), "", CONFIG.Typography.MessageSize, PALETTE.Message, 13),
    }
    
    return self
end

function Notification:SetContent(Title, Message, Type)
    local AccentColor = PALETTE.Accent[Type] or PALETTE.Accent.Info
    self.Drawings.Accent.Color = AccentColor
    self.Drawings.Title.Text = Title
    self.Drawings.Message.Text = Message
end

function Notification:SetTransparency(Transparency)
    local Alpha = 1 - Transparency
    for _, Drawing in pairs(self.Drawings) do
        Drawing.Transparency = Alpha
    end
end

function Notification:SetPosition(X, Y)
    self.Drawings.Background.Position = Vector2.new(X, Y)
    self.Drawings.Border.Position = Vector2.new(X, Y)
    self.Drawings.Accent.Position = Vector2.new(X, Y)
    
    self.Drawings.Title.Position = Vector2.new(
        X + CONFIG.Typography.SidePadding, 
        Y + CONFIG.Typography.TitleOffset
    )
    
    self.Drawings.Message.Position = Vector2.new(
        X + CONFIG.Typography.SidePadding, 
        Y + CONFIG.Typography.MessageOffset
    )
end

function Notification:Destroy()
    for _, Drawing in pairs(self.Drawings) do
        Drawing:Remove()
    end
end

local AnimationManager = {}

function AnimationManager:StartRenderLoop()
    if RenderConnection then return end
    
    RenderConnection = RunService.RenderStepped:Connect(function(DeltaTime)
        local HasActiveNotifications = false
        
        for Index = #NotificationQueue, 1, -1 do
            local NotificationData = NotificationQueue[Index]
            
            NotificationData.CurrentX = Lerp(
                NotificationData.CurrentX, 
                CalculateTargetX(), 
                math.min(DeltaTime * CONFIG.Animation.SlideSpeed, 1)
            )
            
            NotificationData.CurrentY = Lerp(
                NotificationData.CurrentY, 
                NotificationData.TargetY, 
                math.min(DeltaTime * CONFIG.Animation.SlideSpeed, 1)
            )
            
            if NotificationData.State == "FadingIn" then
                NotificationData.Alpha = math.min(
                    NotificationData.Alpha + DeltaTime * CONFIG.Animation.FadeSpeed, 
                    1
                )
                
                if NotificationData.Alpha >= 0.99 then
                    NotificationData.Alpha = 1
                    NotificationData.State = "Holding"
                end
                
            elseif NotificationData.State == "FadingOut" then
                NotificationData.Alpha = math.max(
                    NotificationData.Alpha - DeltaTime * CONFIG.Animation.FadeSpeed, 
                    0
                )
                
                if NotificationData.Alpha <= 0.01 then
                    NotificationData.Object:Destroy()
                    table.remove(NotificationQueue, Index)
                    
                    for Slot, Remaining in ipairs(NotificationQueue) do
                        Remaining.TargetY = CalculateTargetY(Slot)
                    end
                    
                    goto Continue
                end
            end
            
            NotificationData.Object:SetTransparency(NotificationData.Alpha)
            NotificationData.Object:SetPosition(NotificationData.CurrentX, NotificationData.CurrentY)
            
            HasActiveNotifications = true
            
            ::Continue::
        end
        
        if not HasActiveNotifications and RenderConnection then
            RenderConnection:Disconnect()
            RenderConnection = nil
        end
    end)
end

local function Notify(Title, Message, Duration, NotificationType)
    Title = tostring(Title or "Notification")
    Message = tostring(Message or "")
    Duration = Duration or 4
    NotificationType = NotificationType or "info"
    
    local Slot = #NotificationQueue + 1
    local StartX = CalculateTargetX() + CONFIG.Positioning.Offscreen
    local StartY = CalculateTargetY(Slot)
    
    local NotificationObject = Notification.new(StartX, StartY)
    NotificationObject:SetContent(Title, Message, NotificationType)
    
    local NotificationData = {
        Object    = NotificationObject,
        CurrentX  = StartX,
        CurrentY  = StartY,
        TargetY   = StartY,
        Alpha     = 0,
        State     = "FadingIn",
    }
    
    table.insert(NotificationQueue, NotificationData)
    AnimationManager:StartRenderLoop()
    
    task.spawn(function()
        task.wait(Duration)
        for _, Data in ipairs(NotificationQueue) do
            if Data == NotificationData and Data.State == "Holding" then
                Data.State = "FadingOut"
                AnimationManager:StartRenderLoop()
                break
            end
        end
    end)
    
    return NotificationData
end

return Notify
